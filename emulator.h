//
//  emulator.h
//  InterpRust
//
//  Created by xintu on 6/13/23.
//

#ifndef emulator_h
#define emulator_h

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Cpu8080 Cpu8080;

typedef enum Message_Tag {
  Interrupt,
  Suspend,
  Restart,
  Shutdown,
} Message_Tag;

typedef struct Interrupt_Body {
  uint8_t irq_no;
  bool allow_nested_interrupt;
} Interrupt_Body;

typedef struct Message {
  Message_Tag tag;
  union {
    Interrupt_Body interrupt;
  };
} Message;

typedef struct CpuSender {
  struct Cpu8080 *cpu;
  void *sender;
} CpuSender;

typedef struct IoCallbacks {
  /**
   * IN port, pass port number back to app
   * set the calculated result back to reg_a
   */
  uint8_t (*input)(const void *io_object, uint8_t port);
  /**
   * OUT port value, pass port & value back to app
   */
  void (*output)(const void *io_object, uint8_t port, uint8_t value);
} IoCallbacks;

/**
 * # Safety
 * This function should be called with valid rom path
 * and the RAM will be allocated on the fly
 */
struct CpuSender new_cpu_instance(const char *rom_path,
                                  uintptr_t ram_size,
                                  struct IoCallbacks callbacks,
                                  const void *io_object);

/**
 * # Safety
 * This function should be safe
 */
void run(struct Cpu8080 *cpu, void *sender);

/**
 * # Safety
 * This function should be safe for accessing video ram
 */
const uint8_t *get_ram(struct Cpu8080 *cpu);

/**
 * # Safety
 * Always called from a separated thread!
 * It is crucial that we don't borrow our CPU instance
 * since this function will be called from FFI thread.
 * (e.g. threads spawned by Swift language where we
 * cannot enforce any ownership mechanism)
 */
void send_message(void *sender, struct Message message);




#endif /* emulator_h */
