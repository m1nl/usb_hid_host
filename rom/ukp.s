; ---------------------------------------------------------------------------
; Copyright 2023 nand2mario
; Copyright 2026 Mateusz Nalewajski
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
;
; SPDX-License-Identifier: Apache-2.0
; ---------------------------------------------------------------------------

cstart:
; ---- start with high impedance
    hiz

; ---- set interrupt transfer interval
    load 13
cstart2:
    wait
    bc connected
    be cstart2

; ---- wait 200ms after device attached
    save 15 0             ; disconnected, reset watchdog
    ldi 200
w200ms:
    wait
    dec
    bnz w200ms

; ---- enumeration sequence
    call reset            ; reset device

; GET_DESCRIPTOR (Device, 0)
    call setup_frame00
    call get_device
    ldi 128               ; receive 16 bytes of data from device
    start                 ; mark start of read transaction

; IN(0,0), ACK(), device descriptor
    call read_control00
; the buffer wraps, start reading from byte 8
    save 0 0              ; idVendor lsb
    save 1 1              ; idVendor msb
    save 2 2              ; idProduct lsb
    save 3 3              ; idProduct msb
    call status_read00    ; complete control read after saving descriptor bytes

; GET_DESCRIPTOR (Configuration, 0)
    call setup_frame00
    call get_config
    ldi 144               ; receive up to 18 bytes of data from device
    start                 ; mark start of read transaction

; IN(0,0), ACK(), configuration descriptor
    call read_control00
; the buffer wraps, start reading from byte 14
    save 4 6               ; interface class
    save 5 7               ; interface sub-class
    save 6 0               ; interface protocol
    call status_read00    ; complete control read before the next reset/request

; if the device is unsupported or DFU, go to start to make it timeout
    load 14
    bz cstart

; ---- initialization sequence
    call reset            ; reset device again

; SET_ADDRESS (0, 1)
    call setup_frame00
    call set_address

; IN(0,0), ACK()
wait_set_address:
    call frame
    call in00
    call rcvdt
    bnak wait_set_address
    call sendack

; SET_ADDRESS recovery: the first wait may cover only a partial frame.
; Together with SET_CONFIGURATION's wait below, cross three frame boundaries
; to allow at least 2ms after the status ACK, maintaining SOF/keep-alive traffic.
address_recovery:
    call frame
    call frame

; SET_CONFIGURATION (1, 1)
    call setup_frame10
    call set_config

; IN(1,0), ACK()
    ldi 64
    call control_in10
    bstall connerr        ; mandatory configuration request

; skip HID initialization for Xbox 360-compatbile controllers
    load 12
    bnz xinput_init

; SET_IDLE (1, 0)
    call setup_frame10
    call set_idle

; IN(1,0), ACK()
    ldi 64
    call control_in10


; Read the first nine report-descriptor bytes; contents remain unused.
; GET_DESCRIPTOR (HID, 1, 0)
    call setup_frame10
    call get_hid_report
    ldi 72                ; receive 9 bytes of data from device
    start                 ; mark start of read transaction
;
; IN(1,0), ACK() - read but ignore contents
read_get_hid_report:
    call control_in10
    bstall get_hid_report_ready
    bnz read_get_hid_report
    call status_read10
get_hid_report_ready:


; SET_PROTOCOL (1, 0)
    call setup_frame10
    call set_protocol

; IN(1,0), ACK()
    ldi 64
    call control_in10

    bjmp init_finished

xinput_init:
; huge thanks to Jakob
; ref: https://jakob.space/blog/sorry-guys-i-have-to-troubleshoot-my-usb-drivers-before-i-can-play.html
; XINPUT_LED (1)
    call frame
    call out1x
    call xinput_led

; some third-party controllers Xbox 360-style controllers
; require this message to finish initialization
; ref: linux/drivers/input/joystick/xpad.c
; XINPUT_INIT (1)
    call setup_frame10
    call xinput_magic
    ldi 160               ; receive 20 bytes of data from device
    start                 ; mark start of read transaction

; IN(1,0), ACK() - read but ignore contents
read_xinput_magic:
    call control_in10
    bstall xinput_magic_ready
    bnz read_xinput_magic


xinput_magic_ready:

; ---- initialization finished
init_finished:
    save 15 1             ; connected
    bjmp cstart

; ---- interrupt polling
connected:
    call sof
    dec
    bnz cstart2
    start                 ; mark start of read transaction
    call in1x
    ldi 128               ; receive up to 16 bytes of HID report
    call rcvdt2
    bnak cstart
    call sendack
    bjmp cstart

; ---- disconnect and jump start
connerr:
    save 15 0             ; disconnected
    bjmp cstart

; ---- subroutines
reset:
    out4 0x00

; ---- wait 20ms
    ldi 20
loop_reset:
    wait
    dec
    bnz loop_reset
    hiz

; ---- wait 40ms
    ldi 40
w40ms:
    call frame
    dec
    bnz w40ms
    ret

; OUT status stage for control reads made before SET_ADDRESS.
; Descriptor bytes must be saved first: receiving can change the report buffer.
; Keep calls at most two deep, matching the UKP return stack.
status_read00:
    call frame
    outb 0x80             ; SYNC
    outb 0xe1             ; PID=OUT
    outb 0x00             ; ADDR:ENDP=0:0
    outb 0x10             ; + CRC5
    out4 0x03             ; EOP
    hiz
    call status_zlp
    bnak status_read00    ; busy: retry the same DATA1 status transaction
    bstall connerr        ; STALL or receive timeout: restart enumeration
    ret

status_read10:
    call frame
    outb 0x80             ; SYNC
    outb 0xe1             ; PID=OUT
    outb 0x01             ; ADDR:ENDP=1:0
    outb 0xe8             ; + CRC5
    out4 0x03             ; EOP
    hiz
    call status_zlp
    bnak status_read10    ; busy: retry the same DATA1 status transaction
    bstall connerr        ; STALL or receive timeout: restart enumeration
    ret
get_device:               ; get device descriptor of (0,0)
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x80             ; bmRequestType=80
    outb 0x06             ; bRequest=6 (Get_Descriptor)
    outb 0x00             ; Desc Index=0
    outb 0x01             ; Desc Type=1 (device)
    outb 0x00             ; Language ID=0
    outb 0x00             ;
    outb 0x10             ; wLength=16
    outb 0x00
    outb 0xe1             ; CRC16
    outb 0x94
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

get_config:               ; get config descriptor of (0,0)
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x80             ; bmRequestType=0
    outb 0x06             ; bRequest=6 (Get_Descriptor)
    outb 0x00             ; Desc Index=0
    outb 0x02             ; Desc Type=2 (configuration)
    outb 0x00             ; Language ID=0
    outb 0x00             ;
    outb 0x12             ; wLength=18
    outb 0x00
    outb 0xa4             ; CRC16
    outb 0xf4
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

set_address:              ; set address of device 0 to 1
    outb 0x80
    outb 0xc3
    outb 0x00
    outb 0x05
    outb 0x01
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0xeb
    outb 0x25
    out4 0x03
    hiz
    bjmp rcvdt

set_config:               ; set active configuration of device 1 to 1 (default config)
    outb 0x80
    outb 0xc3
    outb 0x00
    outb 0x09
    outb 0x01
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x27
    outb 0x25
    out4 0x03
    hiz
    bjmp rcvdt

set_idle:
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x21             ; bmRequestType=21
    outb 0x0a             ; bRequest=a (Set_Idle)
    outb 0x00             ; wValue=0
    outb 0x00
    outb 0x00             ; wIndex=0
    outb 0x00
    outb 0x00             ; wLength=0
    outb 0x00
    outb 0xd6             ; CRC16
    outb 0x20
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

set_protocol:
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x21             ; bmRequestType=21
    outb 0x0b             ; bRequest=b (Set_Protocol)
    outb 0x00             ; wValue=0
    outb 0x00
    outb 0x00             ; wIndex=0
    outb 0x00
    outb 0x00             ; wLength=0
    outb 0x00
    outb 0xc6             ; CRC16
    outb 0xe0
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

get_hid_report:
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x81             ; bmRequestType=81
    outb 0x06             ; bRequest=6 (Get_Descriptor)
    outb 0x00             ; Desc Index=0
    outb 0x22             ; Desc Type=22 HID
    outb 0x00             ; wInterfaceNumber=0
    outb 0x00
    outb 0x09             ; wLength=9
    outb 0x00
    outb 0xee             ; CRC16
    outb 0x0f
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

xinput_led:
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x01
    outb 0x03
    outb 0x02
    outb 0x5e             ; CRC16
    outb 0xce
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

xinput_magic:
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0xc1             ; bmRequestType=c1
    outb 0x01             ; bRequest=1
    outb 0x00             ; wValue=0x0100
    outb 0x01
    outb 0x00             ; wIndex=0x0000
    outb 0x00
    outb 0x14             ; wLength=20
    outb 0x00
    outb 0x50             ; CRC16
    outb 0x68
    out4 0x03             ; EOP
    hiz
    bjmp rcvdt

rcvdt:
    ldi 64                ; receive up to 8 bytes of data from device by default
rcvdt2:
    in
rcvdt_eop:
    hiz
    be rcvdt_eop          ; wait for line idle
    hiz                   ; ensure delay before next transaction
    ret

setup00:
    outb 0x80             ; SYNC
    outb 0x2d             ; PID
    outb 0x00             ; ADDR:ENDP=0:0
    outb 0x10             ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

setup10:
    outb 0x80             ; SYNC
    outb 0x2d             ; PID
    outb 0x01             ; ADDR:ENDP=1:0
    outb 0xe8             ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

out1x:
    outb 0x80             ; SYNC
    outb 0xe1             ; PID=OUT
    outr 10               ; ADDR:ENDP
    outr 11               ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

in00:
    outb 0x80             ; SYNC
    outb 0x69             ; PID=IN
    outb 0x00             ; ADDR:ENDP=0:0
    outb 0x10             ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

in10:
    outb 0x80             ; SYNC
    outb 0x69             ; PID=IN
    outb 0x01             ; ADDR:ENDP=1:0
    outb 0xe8             ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

in1x:
    outb 0x80             ; SYNC
    outb 0x69             ; PID=IN
    outr 8                ; ADDR:ENDP
    outr 9                ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

sendack:
    outb 0x80
    outb 0xd2
    out4 0x03
    hiz
    ret

sof:
    be connerr
    bnf keep_alive
    outb 0x80
    outb 0xa5
    outb 0x00
    outb 0x10
keep_alive:
    out4 0x03             ; low-speed keep-alive
    hiz
    ret

control_in10:
    call frame
    call in10
    call rcvdt2
    bnak control_in10
    bstall control_in10_ready
    call sendack
control_in10_ready:
    ret

read_control00:
    call frame
    call in00
    call rcvdt2
    bnak read_control00
    bstall connerr
    call sendack
    bnz read_control00
    ret

; Shared control-read status data packet, following an OUT token to endpoint 0.
; The caller checks the handshake flags for ACK, NAK retry, or STALL/timeout.
status_zlp:
    outb 0x80             ; SYNC
    outb 0x4b             ; PID=DATA1, zero-length payload
    outb 0x00             ; CRC16 of empty payload, low byte
    outb 0x00             ; CRC16 high byte
    out4 0x03             ; EOP
    hiz                   ; release bus for the device handshake
    bjmp rcvdt            ; receive handshake; tail jump preserves return stack

setup_frame00:
    call frame
    call setup00
    ret

setup_frame10:
    call frame
    call setup10
    ret

frame:
    wait
    bjmp sof

prgend:
