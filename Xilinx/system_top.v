...

  IOBUF iobuf_usb_dm_0 (
    .I(usb_dm_out[0]),
    .O(usb_dm_in[0]),
    .T(~usb_oe[0]),
    .IO(usb_dm_0)
  );

  IOBUF iobuf_usb_dp_0 (
    .I(usb_dp_out[0]),
    .O(usb_dp_in[0]),
    .T(~usb_oe[0]),
    .IO(usb_dp_0)
  );

  IOBUF iobuf_usb_dm_1 (
    .I(usb_dm_out[1]),
    .O(usb_dm_in[1]),
    .T(~usb_oe[1]),
    .IO(usb_dm_1)
  );

  IOBUF iobuf_usb_dp_1 (
    .I(usb_dp_out[1]),
    .O(usb_dp_in[1]),
    .T(~usb_oe[1]),
    .IO(usb_dp_1)
  );

...
