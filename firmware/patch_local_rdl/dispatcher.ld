PROVIDE(process_new_rdl = 0x40134950);
PROVIDE(process_ble_shadow_delta = 0x40134a64);

SECTIONS
{
  .literal 0x40123e00 : { *(.literal.aster_rdl_dispatch) *(.literal*) }
  .text 0x40123e14 : { *(.text.aster_rdl_dispatch) *(.text*) }
}
