//
//  Bridge.h
//  Signed
//
//  Created by Markus Moenig on 18/9/23.
//

#ifndef Bridge_h
#define Bridge_h

#include <stdint.h>
static inline void storeAsF16(float value, uint16_t *pointer) { *(__fp16 *)pointer = value; }

#include "Metal.h"

#endif /* Bridge_h */
