// Copyright (c) Meta Platforms, Inc. and affiliates.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted.
//
// fishhook: a library for dynamically rebinding symbols in Mach-O binaries

#ifndef fishhook_h
#define fishhook_h

#include <stddef.h>
#include <stdint.h>

struct rebinding {
    const char *name;
    void *replacement;
    void **replaced;
};

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);
int rebind_symbols_image(void *header, intptr_t slide,
                         struct rebinding rebindings[], size_t rebindings_nel);

#endif /* fishhook_h */
