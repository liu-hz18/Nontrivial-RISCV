package exception;

// exception types (interrupts are not included)

// priority: interrupt > exception
// !interrupt handle priority from high to low
// mei > msi > mti > sei > ssi > sti
// !exception handle priority from high to low
// i-breakpoint > i-page fault > i-access fault >
// illegal inst > inst_addr_misaligned > 
// ecall > ebreak > 
// store-addr misaligned > load-addr misaligned >
// store-page fault > load page fault >
// store-access fault > load-access fault

typedef struct packed {
  logic
    fetch_access_fault, fetch_pagefault, // ifu exceptions
    load_access_fault, load_pagefault, // lsu exceptions
    store_access_fault, store_pagefault,
    fetch_misalign, load_misalign, store_misalign, // exu exceptions (control-flow instructions)
    ecall, // idu exceptions
    mret, sret, uret,
    illegal_inst, breakpoint;
} except_t;

endpackage
