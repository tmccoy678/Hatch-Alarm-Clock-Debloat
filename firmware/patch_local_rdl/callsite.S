    .section .text.callsite,"ax"
    .global aster_callsite
aster_callsite:
    call8 aster_rdl_dispatch
