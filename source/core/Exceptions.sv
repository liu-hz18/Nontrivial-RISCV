package exception;

// exception types (interrupts are not included)
typedef struct packed {
  logic
    fetch_access_fault, fetch_pagefault, // ifu exceptions
    load_access_fault, load_pagefault, // lsu exceptions
    store_access_fault, store_pagefault,
    fetch_misalign, load_misalign, store_misalign, // exu exceptions (control-flow instructions)
    ecall, // idu exceptions
    mret, sret, uret,
    illegal_inst, breakpoint,
    timer_int; // interruptions from MMIO
} except_t;

endpackage
