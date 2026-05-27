# =============================================================================
# Makefile for Multi-Precision Integer Lab (32-bit Assembly)
# =============================================================================

# Compiler and Assembler definitions
ASM         := nasm
CC          := gcc

# Compilation flags
# -f elf32: Output 32-bit ELF object format
ASMFLAGS    := -f elf32 -g
# -m32: Force GCC to generate 32-bit code and link 32-bit libraries
CFLAGS      := -m32 -g

# Target executable name
TARGET      := multi

# Source and Object files
SRC         := multi.asm
OBJ         := multi.o

# Default target (called when running 'make')
all: $(TARGET)

# Link rule: combines object files into the final executable
$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) $(OBJ) -o $(TARGET)
	@echo "Linking complete. Executable '$(TARGET)' created successfully."

# Assembly rule: converts source files into object files
$(OBJ): $(SRC)
	$(ASM) $(ASMFLAGS) $(SRC) -o $(OBJ)
	@echo "Assembly complete. Object file '$(OBJ)' created."

# Clean rule: removes generated object files and executables
clean:
	rm -f $(OBJ) $(TARGET)
	@echo "Clean complete. Removed build artifacts."

# Phony targets declaration (prevents conflicts with files named 'clean' or 'all')
.PHONY: all clean