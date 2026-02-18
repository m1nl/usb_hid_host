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
    bnf long_interval
    ldi 5
    jmp cstart2
long_interval:
    ldi 10
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
    wait
    call sof
    call setup00
    call get_device
    call rcvdt
    ldi 144               ; receive 18 bytes of data from device
    start                 ; mark start of read transaction

; IN(0,0), ACK(), device descriptor
wait_get_device:
    wait
    call sof
    call in00
    call rcvdt2
    bnak wait_get_device
    call sendack
    bnz wait_get_device
    ldi 8                 ; set packet offset
    save 0 0              ; idVendor lsb
    save 1 1              ; idVendor msb
    save 2 2              ; idProduct lsb
    save 3 3              ; idProduct msb

; GET_DESCRIPTOR (Configuration, 0)
    wait
    call sof
    call setup00
    call get_config
    call rcvdt
    ldi 144               ; receive up to 18 bytes of data from device
    start                 ; mark start of read transaction

; IN(0,0), ACK(), configuration descriptor
wait_get_config:
    wait
    call sof
    call in00
    call rcvdt2
    bnak wait_get_config
    call sendack
    bnz wait_get_config
    ldi 14                ; set packet offset
    save 4 0              ; interface class
    save 5 1              ; interface sub-class
    save 6 2              ; interface protocol

; ---- initialization sequence
    call reset            ; reset device again

; SET_ADDRESS (0, 1)
    wait
    call sof
    call setup00
    call set_address
    call rcvdt

; IN(0,0), ACK()
wait_set_address:
    wait
    call sof
    call in00
    call rcvdt
    bnak wait_set_address
    call sendack

; SET_CONFIGURATION (1, 1)
    wait
    call sof
    call setup10
    call set_config
    call rcvdt

; IN(1,0), ACK()
wait_set_config:
    wait
    call sof
    call in10
    call rcvdt
    bnak wait_set_config
    call sendack

; SET_IDLE (0, 1)
    wait
    call sof
    call setup10
    call set_idle
    call rcvdt

; IN(1,0), ACK()
wait_set_idle:
    wait
    call sof
    call in10
    call rcvdt
    bstall set_idle_ready
    bnak wait_set_idle
    call sendack

; GET_DESCRIPTOR (HID, 1)
set_idle_ready:
    wait
    call sof
    call setup10
    call get_hid_report
    call rcvdt
    ldi 72                ; receive 9 bytes of data from device
    start                 ; mark start of read transaction

; IN(1,0), ACK() - read but ignore contents
wait_get_hid_report:
    wait
    call sof
    call in10
    call rcvdt2
    bstall get_hid_report_ready
    bnak wait_get_hid_report
    call sendack
    bnz wait_get_hid_report

; ---- initialization finished
get_hid_report_ready:
    save 15 1             ; connected
    jmp cstart

; ---- interrupt polling
connected:
    call sof
    dec
    bnz cstart2
    start                 ; mark start of read transaction
    call in1x
    call rcvdt
    bnak cstart
    call sendack
    jmp cstart

; ---- disconnect and jump start
connerr:
    save 15 0             ; disconnected
    jmp cstart

; ---- subroutines
reset:
    out0

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
    wait
    call sof
    dec
    bnz w40ms
    ret

get_device:               ; get device descriptor of (0,0)
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x80             ; bmRequestType: 80
    outb 0x06             ; bRequest=6 Get_Descriptor
    outb 0x00             ; Desc Index: 0
    outb 0x01             ; Desc Type: 1 device
    outb 0x00             ; Language ID: 0
    outb 0x00             ;
    outb 0x12             ; wLength = 18
    outb 0x00
    outb 0xe0             ; CRC16
    outb 0xf4
    out4 0x03             ; EOP
    hiz
    ret

get_config:               ; get config descriptor of (0,0)
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x80             ; bmRequestType: 0
    outb 0x06             ; bRequest=6 Get_Descriptor
    outb 0x00             ; Desc Index: 0
    outb 0x02             ; Desc Type: 2 configuration
    outb 0x00             ; Language ID: 0
    outb 0x00             ;
    outb 0x12             ; wLength = 18
    outb 0x00
    outb 0xa4             ; CRC16
    outb 0xf4
    out4 0x03             ; EOP
    hiz
    ret

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
    ret

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
    ret

set_idle:
    outb 0x80
    outb 0xc3
    outb 0x21
    outb 0x0a
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0x00
    outb 0xd6
    outb 0x20
    out4 0x03
    hiz
    ret

get_hid_report:
    outb 0x80             ; SYNC
    outb 0xc3             ; PID=DATA0
    outb 0x81             ; bmRequestType: 81
    outb 0x06             ; bRequest=6 Get_Descriptor
    outb 0x00             ; Desc Index: 0
    outb 0x22             ; Desc Type: 22 HID
    outb 0x00             ; Language ID: 0
    outb 0x00             ;
    outb 0x09             ; wLength = 9
    outb 0x00
    outb 0xee             ; CRC16
    outb 0x0f
    out4 0x03             ; EOP
    hiz
    ret

rcvdt:
    ldi 72                ; receive up to 9 bytes of data from device by default
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
    outb 0x00             ; ADDR:ENDP = 0:0
    outb 0x10             ; + CRC5
    out4 0x03             ; EOP
    hiz
    ret

setup10:
    outb 0x80
    outb 0x2d
    outb 0x01
    outb 0xe8
    out4 0x03
    hiz
    ret

in00:
    outb 0x80
    outb 0x69
    outb 0x00
    outb 0x10
    out4 0x03
    hiz
    ret

in10:
    outb 0x80
    outb 0x69
    outb 0x01
    outb 0xe8
    out4 0x03
    hiz
    ret

in1x:
    outb 0x80
    outb 0x69
    outr 0x08
    outr 0x09
    out4 0x03
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

prgend:
