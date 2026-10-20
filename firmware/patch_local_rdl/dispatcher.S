    .section .literal.aster_rdl_dispatch,"a"
    .align 4
aster_marker:
    .long 0x615f227b

    .section .text.aster_rdl_dispatch,"ax"
    .align 4
    .global aster_rdl_dispatch
    .type aster_rdl_dispatch,@function
aster_rdl_dispatch:
    entry a1, 32
    bltui a3, 4, .Lfallback
    l32i a8, a2, 0
    l32r a9, aster_marker
    bne a8, a9, .Lfallback

    mov a10, a2
    mov a11, a3
    movi a12, 0
    movi a13, 0
    call8 process_new_rdl
    movi a2, 1
    retw.n

.Lfallback:
    mov a10, a2
    mov a11, a3
    call8 process_ble_shadow_delta
    mov a2, a10
    retw.n
    .size aster_rdl_dispatch, .-aster_rdl_dispatch
