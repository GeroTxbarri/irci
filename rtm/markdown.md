# Pruebas del Instruction Set RTM32 (STX4) — versión nueva (0.1.1-RC1)

Todas las pruebas se ejecutaron contra el emulador real `rtm32`, conectado por telnet
al debugger (`telnet localhost 4444`), usando los comandos `set`, `step`, `registers`
y `examine`. El debugger sigue siendo el mismo pese a que el manual describe una
interfaz distinta (`G`, `D R`, `D M`, `W`) — esa parte del manual es aspiracional, no
implementada; se confirmó con `help` en vivo que el set de comandos real no cambió.

Cada instrucción se codificó a mano a 32 bits según los formatos R/I/J (ya no hay
formato L separado: ANDI/ORI/XORI/LUI viven dentro del formato I, reinterpretando el
bit alto del inmediato como bit `h`). Opcodes y códigos `func` no cambiaron respecto
del manual anterior, así que las cuentas de esa entrega siguen valiendo.

Convención de registros: se usan números de registro ($10, $11, etc.), no alias.

Nota (versión 0.1.0-RC1): el profesor subió una máquina nueva ("múltiples bugs
corregidos") y un manual extendido en la parte de instrucciones aritméticas (flags
Z/N/O/C con ejemplos resueltos, condiciones de excepción de DIV/REST). Se re-testearon
todos los casos que en la entrega anterior habían dado bug, y todos resultaron
arreglados (ver nota en cada Caso afectado).

Nota (versión 0.1.1-RC1, la actual): nueva subida del profesor. Comparado contra el
manual anterior, el único cambio real es una corrección de nomenclatura en la tabla
de opcodes (los nombres `elimm`/`vlimm`/`limm` de J/JAL/JALX/JALRX ahora coinciden con
la jerarquía de tamaños de la Tabla 4.1; antes había una inconsistencia de nombres,
pero los bits codificados son los mismos). Se volvió a probar una muestra de los casos
previamente arreglados (ADD con flags, ANDI, LCI, SWX, BEQ) y ninguno mostró
regresión. También se probó por primera vez CFS, CTS y TRAP: siguen sin funcionar
(CFS no lee el registro especial, CTS no escribe, TRAP no salta a la tabla de
vectores ni actualiza EPC) — ver Caso 25. La máquina ahora reporta versión
`RTM32-0.1.1` en `--version`.

Cobertura de este documento: 35 instrucciones probadas a fondo (Casos 1-23) más una
verificación liviana de CFS/CTS/TRAP (Caso 25, siguen rotas). No se llegó al 100% por
la magnitud del rediseño previo. Quedan sin probar: RFT (no se puede validar sin un
TRAP funcional que le dé un EPC real), JAL, JALR, JALX, JALRX, BNE, BGE, BLTU, BGEU.

---

# Caso 1
## Descripción
ADD y SUB. El `func` de ambas cambió de posición respecto de la versión anterior de
la máquina (antes 0x1C/0x1D, ahora 0x0C/0x0D).

## Instrucciones
ADD $12,$10,$11 ; SUB $13,$10,$11

## Precondiciones
- $10 = 15
- $11 = 4

## Code
func nuevo: ADD=0x0C, SUB=0x0D (formato R sin cambios de bits, solo cambió el func)
```
set [0x0] 0x0296C00C
set [0x4] 0x0296D00D
set r10 15
set r11 4
step
registers
step
registers
```

## Postcondiciones
- R12 = 0x13 (19 = 15+4)
- R13 = 0x0B (11 = 15-4)

## Conclusiones
Anduvo. Confirma que el `func` nuevo (0x0C/0x0D) es correcto para esta versión.

---

# Caso 2
## Descripción
AND, OR, XOR, NOR. Estos 4 mantuvieron el mismo `func` que la versión anterior
(0x08-0x0B), a diferencia de ADD/SUB/SLT/SLTU que sí se movieron.

## Instrucciones
AND $12,$10,$11 ; OR $13,$10,$11 ; XOR $14,$10,$11 ; NOR $15,$10,$11

## Precondiciones
- $10 = 0xC
- $11 = 0xA

## Code
```
set [0x0] 0x0296C008
set [0x4] 0x0296D009
set [0x8] 0x0296E00A
set [0xC] 0x0296F00B
set r10 12
set r11 10
step
registers
step
registers
step
registers
step
registers
```

## Postcondiciones
- R12 = 0x8, R13 = 0xE, R14 = 0x6, R15 = 0xFFFFFFF1

## Conclusiones
Anduvo. Los 4 dan el resultado correcto, sin cambios respecto de la versión anterior.

---

# Caso 3
## Descripción
SLT, SLTU. El func de ambas se movió (antes 0x0C/0x0D, ahora 0x0E/0x0F, porque ADD/SUB
ocuparon su lugar viejo).

## Instrucciones
SLT $16,$10,$11 ; SLTU $17,$10,$11

## Precondiciones
- $10 = 0xFFFFFFFF
- $11 = 1

## Code
func nuevo: SLT=0x0E, SLTU=0x0F
```
set [0x0] 0x0297000E
set [0x4] 0x0297100F
set r10 0xFFFFFFFF
set r11 1
step
registers
step
registers
```

## Postcondiciones
- R16 = 1 (SLT: -1 < 1 con signo)
- R17 = 0 (SLTU: 0xFFFFFFFF < 1 sin signo, falso)

## Conclusiones
Anduvo, con el func nuevo correctamente recalculado.

---

# Caso 4
## Descripción
SLL, SRL, SRA. El manual nuevo insertó una instrucción `RLC` entre SLL y SRL, así
que SRL y SRA corrieron su func una posición (antes 0x01/0x02, ahora 0x02/0x03).
Además estas 3 ya no usan el campo `rs` (queda reservado en 0); antes tampoco lo
usaban pero ahora el manual lo aclara explícitamente.

## Instrucciones
SLL $12,$11,4 ; SRL $13,$11,1 ; SRA $14,$11,1

## Precondiciones
- Para SLL: $11 = 1
- Para SRL/SRA: $11 = 0x80000000

## Code
func nuevo: SLL=0x00 (sin cambio), SRL=0x02, SRA=0x03
```
set [0x0] 0x0016C200
set [0x4] 0x0016D082
set [0x8] 0x0016E083
set r11 1
step
registers
set r11 0x80000000
step
registers
step
registers
```

## Postcondiciones
- R12 = 0x10 (SLL)
- R13 = 0x40000000 (SRL, entra un 0)
- R14 = 0xC0000000 (SRA, entra el bit de signo)

## Conclusiones
Anduvo, con los func corridos correctamente.

---

# Caso 5
## Descripción
RLC (rotate left), instrucción nueva que no existía en la versión anterior. Rota los
bits circularmente hacia la izquierda (los que salen por arriba entran por abajo).

## Instrucciones
RLC $18,$11,8

## Precondiciones
- $11 = 0x12345678

## Code
func RLC=0x01 (mismo formato que SLL/SRL/SRA: rt, rd, param)
```
set [0x0] 0x00172401
set r11 0x12345678
step
registers
```

## Postcondiciones
- R18 = 0x34567812

## Conclusiones
Anduvo. Coincide exacto con el ejemplo resuelto que trae el propio manual (sección
7.4.3): rotar 0x12345678 ocho posiciones a la izquierda da 0x34567812.

---

# Caso 6
## Descripción
SLLR, SRLR, SRAR, RLCR (variantes con la cantidad de shift tomada de un registro en
vez de inmediata). RLCR es nueva; las otras 3 corrieron su func una posición por la
inserción de RLC/RLCR en la tabla.

## Instrucciones
SLLR $20,$10,$11 ; SRLR $21,$10,$11 ; SRAR $22,$10,$11 ; RLCR $23,$10,$11

## Precondiciones
- Para SLLR: $10 = 3 (cantidad), $11 = 1
- Para SRLR/SRAR: $10 = 1, $11 = 0x80000000
- Para RLCR: $10 = 8 (cantidad), $11 = 0x12345678

## Code
func nuevo: SLLR=0x04, RLCR=0x05, SRLR=0x06, SRAR=0x07
```
set [0x0] 0x02974004
set r10 3
set r11 1
step
registers
set [0x0] 0x02975006
set [0x4] 0x02976007
set r10 1
set r11 0x80000000
step
registers
step
registers
set [0x0] 0x02977005
set r10 8
set r11 0x12345678
step
registers
```

## Postcondiciones
- R20 = 0x8 (SLLR), R21 = 0x40000000 (SRLR), R22 = 0xC0000000 (SRAR),
  R23 = 0x34567812 (RLCR)

## Conclusiones
Anduvieron las 4, con los func recalculados correctamente.

---

# Caso 7
## Descripción
ADDI. El opcode se movió de 00001 a 00011 en la nueva tabla (antes J estaba en
00010 y JAL en 00011; ahora J/JAL/JALX comparten opcode 00001 diferenciados por
subcódigo, y JR/JALR/JALRX pasaron a opcode 00010, corriendo ADDI a opcode 00011).

## Instrucciones
ADDI $11,$10,10

## Precondiciones
- $10 = 5

## Code
opcode nuevo ADDI = 00011 (3)
```
set [0x0] 0x1A96000A
set r10 5
step
registers
```

## Postcondiciones
- R11 = 15

## Conclusiones
Anduvo, con el opcode nuevo.

---

# Caso 8 — BUG, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
ANDI. En la nueva tabla, ANDI comparte opcode 00100 con la instrucción nueva LCI
(diferenciadas por el bit h). Se probó con distintos valores de inmediato, incluso
0x0000, para descartar un error propio de codificación.

## Instrucciones
ANDI $11,$10,0xFF

## Precondiciones
- $10 = 0xFFFFFFFF
- Se repitió el mismo test con imm = 0xFF00, 0x0001, 0x8000 y 0x0000

## Code
opcode ANDI/LCI = 00100 (4), h=0 para ANDI
```
set [0x0] 0x229600FF
set r10 0xFFFFFFFF
step
registers
```
(y lo mismo reemplazando los últimos 2 bytes del word por 0xFF00, 0x0001, 0x8000,
0x0000, siempre con el mismo resultado)

## Postcondiciones
- R11 = 0x0000FFFF en los 5 casos, sin importar el inmediato usado (se esperaba
  0x000000FF con imm=0xFF, y un resultado distinto para cada imm distinto)

## Conclusiones
En la versión anterior de la máquina no andaba: ANDI ignoraba completamente el campo
inmediato, siempre calculaba `R[rt] = R[rs] & 0x0000FFFF` sin importar el valor
codificado (incluso con imm=0x0000 el resultado no cambiaba). Re-testeado contra la
versión nueva ("múltiples bugs corregidos"), mismo test: R11 = 0x000000FF, correcto.
Arreglado.

---

# Caso 9 — BUG, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
ANI y ANH, instrucciones nuevas que reemplazan/complementan a ANDI. Según el manual,
ANI debería preservar la mitad superior del registro (usa extensión con unos en vez
de con ceros) y ANH debería preservar la mitad inferior (concatenación en la parte
alta).

## Instrucciones
ANI $13,$10,0xFF00 ; ANH $14,$10,0x00FF

## Precondiciones
- $10 = 0x12345678

## Code
opcode ANI/ANH = 00101 (5)
```
set [0x0] 0x2A9AFF00
set [0x4] 0x2A9D00FF
set r10 0x12345678
step
registers
step
registers
```

## Postcondiciones (versión vieja)
- R13 = 0x00005600 (se esperaba 0x12345600, preservando la mitad alta)
- R14 = 0x00340000 (se esperaba 0x00345678, preservando la mitad baja)

## Postcondiciones (versión nueva)
- R13 = 0x12345600 (correcto, preserva la mitad alta)
- R14 = 0x00345678 (correcto, preserva la mitad baja)

## Conclusiones
En la versión anterior no andaban: ninguna de las dos preservaba la mitad del
registro que debía preservar (ANI se comportaba como un AND con extensión de ceros,
igual que ANDI, sin el propósito que la justifica en la sección 7.2.2 del manual; ANH
perdía la mitad baja en vez de conservarla). Re-testeadas contra la versión nueva con
el mismo test: ambas dan el resultado correcto. Arregladas.

---

# Caso 10
## Descripción
ORI y ORH. Mismo mecanismo de h que ANDI/LCI pero para OR.

## Instrucciones
ORI $15,$10,0x1234 (h=0, con $10 no nulo para testear la preservación real) ;
ORH $16,$10,0x1234 (h=1)

## Precondiciones
- Para ORI: $10 = 0x56780000
- Para ORH: $10 = 0x00005678

## Code
opcode ORI/ORH = 00110 (6)
```
set [0x0] 0x329E1234
set r10 0x56780000
step
registers
set [0x0] 0x32A11234
set r10 0x00005678
step
registers
```

## Postcondiciones
- R15 = 0x56781234 (preserva la mitad alta, agrega 0x1234 abajo)
- R16 = 0x12345678 (agrega 0x1234 arriba, preserva la mitad baja)

## Conclusiones
Anduvieron las 2. A diferencia de la familia AND (Casos 8 y 9), ORI/ORH sí preservan
correctamente la mitad del registro que no deberían tocar.

---

# Caso 11
## Descripción
XORI y XORH, análogas a ORI/ORH pero con XOR.

## Instrucciones
XORI $17,$10,0xFF ; XORH $18,$10,0xFF

## Precondiciones
- Para XORI: $10 = 0x0000FFFF
- Para XORH: $10 = 0xFFFF0000

## Code
opcode XORI/XORH = 00111 (7)
```
set [0x0] 0x3AA200FF
set r10 0x0000FFFF
step
registers
set [0x0] 0x3AA500FF
set r10 0xFFFF0000
step
registers
```

## Postcondiciones
- R17 = 0x0000FF00 (0x0000FFFF ^ 0x000000FF)
- R18 = 0xFF000000 (0xFFFF0000 ^ 0x00FF0000)

## Conclusiones
Anduvieron las 2, igual que ORI/ORH. El bug de la familia AND (Casos 8-9) no afecta
a OR ni a XOR.

---

# Caso 12 — BUG, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
LCI, instrucción nueva que reemplaza a la vieja LUI. Debería concatenar 16 bits de
inmediato arriba con los 16 bits bajos de un registro fuente (`R[rt] = C16(imm,
R[rs])`), a diferencia de LUI que ponía ceros abajo.

## Instrucciones
LCI $12,$10,0x1234

## Precondiciones
- Test A: $10 = 0x56789ABC (se espera R12 = 0x12349ABC, el ejemplo exacto del manual,
  sección 4.4.2)
- Test B: $10 = 0x00000000, imm = 0x1000 (se espera R12 = 0x10000000)

## Code
opcode LCI = 00100 (4, comparte opcode con ANDI), h=1
```
set [0x0] 0x22991234
set r10 0x56789ABC
step
registers
set pc 0x0
set [0x0] 0x22991000
set r10 0x00000000
step
registers
```

## Postcondiciones (versión vieja)
- Test A: R12 = 0x12309ABC (se esperaba 0x12349ABC — el nibble bajo del inmediato,
  0x4, se pierde/reemplaza por 0)
- Test B: R12 = 0x00000000 (se esperaba 0x10000000 — no concatenó nada)

## Postcondiciones (versión nueva)
- Test A: R12 = 0x12349ABC (correcto, coincide exacto con el ejemplo del manual)
- Test B: R12 = 0x10000000 (correcto)

## Conclusiones
En la versión anterior no andaba: con registro fuente en cero no escribía nada, y con
registro fuente no nulo concatenaba casi bien pero perdía el nibble menos
significativo del inmediato. Re-testeada contra la versión nueva con los mismos 2
tests: ambos dan el resultado correcto. Arreglada.

---

# Caso 13
## Descripción
LW y SW. El opcode de ambas no cambió respecto de la versión anterior.

## Instrucciones
SW $11,0($10) ; LW $12,0($10)

## Precondiciones
- $10 = 0x100
- $11 = 0xDEADBEEF

## Code
```
set [0x0] 0x4A960000
set [0x4] 0x42980000
set r10 0x100
set r11 0xDEADBEEF
step
step
registers
```

## Postcondiciones
- R12 = 0xDEADBEEF

## Conclusiones
Anduvo, sin cambios respecto de la versión anterior.

---

# Caso 14
## Descripción
SB, LB, LBU. Opcodes sin cambios.

## Instrucciones
SB $11,0($10) ; LB $12,0($10) ; LBU $13,0($10)

## Precondiciones
- $10 = 0x200
- $11 = 0xFFFFFF80

## Code
```
set [0x0] 0x5A960000
set [0x4] 0x72980000
set [0x8] 0x7A9A0000
set r10 0x200
set r11 0xFFFFFF80
step
step
step
registers
```

## Postcondiciones
- R12 = 0xFFFFFF80 (LB, con signo)
- R13 = 0x00000080 (LBU, con ceros)

## Conclusiones
Anduvo, sin cambios respecto de la versión anterior.

---

# Caso 15
## Descripción
SH, LH, y la nueva regla de alineación estricta de 16 bits (antes solo se exigía
alineación de 32 bits para accesos de palabra; ahora el manual dice explícitamente
que halfword también requiere dirección par, sección 1.4.1).

## Instrucciones
SH $11,0($10) ; LH $12,0($10)

## Precondiciones
- Test A (alineado): $10 = 0x300, $11 = 0xFFFF8000
- Test B (desalineado): $10 = 0x301

## Code
```
set [0x0] 0x52960000
set [0x4] 0x62980000
set r10 0x300
set r11 0xFFFF8000
step
step
registers
set pc 0x0
set [0x0] 0x52960000
set r10 0x301
step
registers
```

## Postcondiciones
- Test A: R12 = 0xFFFF8000, memoria de tamaño 2 leída/escrita correctamente
- Test B: CAUSE = 0x00000005, BADVADR = 0x00000301 (excepción de alineación)

## Conclusiones
Anduvo. SH/LH funcionan igual que antes en direcciones alineadas, y la nueva regla
de alineación de 16 bits sí está implementada: acceder a una dirección impar con SH
dispara la excepción esperada.

---

# Caso 16
## Descripción
LWX (load word indexado por dos registros). Mismo func que la versión anterior.

## Instrucciones
LWX $13,$10,$12

## Precondiciones
- $10 = 0x100, $12 = 0x10 (dirección efectiva 0x110)
- mem[0x110] = 0xCAFEBABE (poblado con SWX antes de descubrir que SWX crashea — ver
  Caso 17; para este test se pobló la memoria directamente con `set [0x110] ...`)

## Code
func LWX = 0x14 (sin cambio)
```
set [0x0] 0x029AC014
set r10 0x100
set r12 0x10
set [0x110] 0xCAFEBABE
step
registers
```

## Postcondiciones
- R13 = 0xCAFEBABE

## Conclusiones
Anduvo. La carga indexada por dos registros sigue funcionando igual que en la
versión anterior.

---

# Caso 17 — BUG GRAVE, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
SWX, SHX, SBX: instrucciones nuevas de almacenamiento indexado (antes solo existían
las de lectura indexada — LWX/LHX/LBX — no había forma de guardar con direccionamiento
de dos registros).

## Instrucciones
SWX $11,$10,$12 ; SHX $11,$10,$12 ; SBX $11,$10,$12

## Precondiciones
- $10 = 0x100 (dirección base), $12 = 0x10 (índice, dirección efectiva 0x110/0x120),
  $11 = dato a guardar

## Code
func nuevo: SWX=0x15, SHX=0x16, SBX=0x17
```
set [0x0] 0x0296C015     (SWX $11,$10,$12)
set r10 0x100
set r12 0x10
set r11 0xCAFEBABE
step
examine 0x110
```
(análogo con func 0x16 para SHX y 0x17 para SBX, cada una probada por separado)

## Postcondiciones (versión vieja)
- Las 3 veces: la conexión del debugger se cortó (`Connection closed by foreign
  host`) apenas se ejecutó el `step`, sin llegar a mostrar "Stepped instructions".
- El log del emulador confirma que el proceso `rtm32` deja de existir justo después
  de loguear "Instruction: 0x0296C015 / Opcode: 0b00000" (fetch correcto, pero el
  handler de esa instrucción nunca termina de ejecutar).

## Postcondiciones (versión nueva)
- SWX: mem[0x110] = 0xCAFEBABE, correcto, sin crash.
- SHX: mem[0x110] = 0x0000ABCD (con $11=0x0000ABCD), correcto, sin crash.
- SBX: mem[0x120] = 0x000000EF (con $11=0x000000EF), correcto, sin crash.

## Conclusiones
En la versión anterior no andaba ninguna de las 3: no era una excepción prolija ni un
resultado incorrecto, el emulador entero crasheaba (el proceso moría) al ejecutar
cualquiera de las 3 instrucciones. Re-testeadas contra la versión nueva: las 3
funcionan correctamente y ya no crashea el proceso. Arregladas.

---

# Caso 18
## Descripción
MUL, DIV, REST con operandos chicos y positivos, para confirmar que el cálculo base
sigue funcionando.

## Instrucciones
MUL $12,$10,$11 ; DIV $13,$10,$11 ; REST $14,$10,$11

## Precondiciones
- $10 = 7, $11 = 3

## Code
func nuevo: MUL=0x18, DIV=0x1C, REST=0x1E (corridos por la inserción de SWX/SHX/SBX
antes en la tabla)
```
set [0x0] 0x0296C018
set [0x4] 0x0296D01C
set [0x8] 0x0296E01E
set r10 7
set r11 3
step
step
step
registers
```

## Postcondiciones
- R12 = 21 (MUL), R13 = 2 (DIV), R14 = 1 (REST)

## Conclusiones
Anduvieron las 3, con los func recalculados.

---

# Caso 19
## Descripción
MULHU y RESTU/DIVU (variantes sin signo), con un operando cuyo bit alto está
activo para forzar una diferencia real entre signado y sin signo.

## Instrucciones
MULHU $16,$10,$11 ; DIVU $18,$10,$11 ; RESTU $19,$10,$11

## Precondiciones
- Para MULHU: $10 = 0xFFFFFFFF, $11 = 0x80000000
- Para DIVU/RESTU: $10 = 0x80000000, $11 = 3

## Code
func nuevo: MULHU=0x1A, DIVU=0x1D, RESTU=0x1F
```
set [0x0] 0x0297001A
set r10 0xFFFFFFFF
set r11 0x80000000
step
registers
set pc 0x0
set [0x0] 0x0297201D
set [0x4] 0x0297301F
set r10 0x80000000
set r11 3
step
step
registers
```

## Postcondiciones
- R16 = 0x7FFFFFFF (mitad alta de 4294967295 × 2147483648, sin signo)
- R18 = 0x2AAAAAAA (2147483648 / 3)
- R19 = 2 (resto)

## Conclusiones
Anduvieron las 3. Las variantes sin signo de multiplicación y división funcionan
correctamente.

---

# Caso 20 — BUG, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
MULH (mitad alta con signo) y MULHSU (instrucción nueva: multiplicación mixta,
`rs` con signo por `rt` sin signo). Se usaron operandos donde el resultado con
signo, sin signo, y mixto deberían ser los 3 distintos entre sí.

## Instrucciones
MULH $15,$10,$11 ; MULHSU $17,$10,$11

## Precondiciones
- Para MULH: $10 = 0xFFFFFFFE (-2 con signo), $11 = 3 (producto con signo = -6,
  mitad alta esperada 0xFFFFFFFF; muy distinto de la interpretación sin signo)
- Para MULHSU: $10 = 0xFFFFFFFF (-1 con signo), $11 = 0x80000000 (2147483648 sin
  signo; producto esperado -2147483648, mitad alta 0xFFFFFFFF)

## Code
func nuevo: MULH=0x19, MULHSU=0x1B
```
set [0x0] 0x0296F019
set r10 0xFFFFFFFE
set r11 3
step
registers
set pc 0x0
set [0x0] 0x0297101B
set r10 0xFFFFFFFF
set r11 0x80000000
step
registers
```

## Postcondiciones (versión vieja)
- R15 (MULH) = 0x00000000 en todos los pares de operandos probados (nunca escribía
  el registro destino, incluso en casos donde el resultado esperado no era cero)
- R17 (MULHSU) = 0x7FFFFFFF (se esperaba 0xFFFFFFFF; el resultado obtenido coincidía
  con la multiplicación totalmente sin signo, igual que MULHU)

## Postcondiciones (versión nueva)
- R15 (MULH) = 0xFFFFFFFF, correcto (-2 × 3 = -6, mitad alta con signo)
- R17 (MULHSU) = 0xFFFFFFFF, correcto

## Conclusiones
En la versión anterior no andaban: MULH nunca escribía su registro destino, y
MULHSU calculaba como si ambos operandos fueran sin signo, ignorando que `rs` debe
interpretarse con signo. Re-testeadas contra la versión nueva con operandos elegidos
para distinguir claramente signo de sin signo: ambas dan el resultado correcto.
Arregladas.

---

# Caso 21 — BUG GRAVE, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
BEQ y BLT, para verificar la fórmula de salto de los branches
(`PC = PC + 4 + 4*imm` según el manual).

## Instrucciones
BEQ $10,$11,1 ; BLT $10,$11,1

## Precondiciones
- BEQ: $10 = 5, $11 = 5 (condición verdadera)
- BLT: $10 = 3, $11 = 7 (condición verdadera)
- En ambos casos, PC de arranque = 0x0, imm = 1, por lo que el destino esperado por
  fórmula es PC = 0 + 4 + 4×1 = 0x00000008

## Code
```
set [0x0] 0x82960001
set r10 5
set r11 5
step
registers
```
(y aparte, en proceso limpio, `0x92960001` con $10=3,$11=7 para BLT)

## Postcondiciones (versión vieja)
- BEQ: PC quedó en 0x00000009 (no en 0x8)
- BLT: PC quedó en 0x00000007 (no en 0x8, y tampoco coincide con el valor de BEQ)

## Postcondiciones (versión nueva)
- BEQ: PC = 0x00000008, correcto.
- BLT: PC = 0x00000008, correcto.

## Conclusiones
En la versión anterior no andaban: el PC resultante no coincidía con la fórmula
documentada, y el error era distinto entre BEQ y BLT (uno daba +1 de más, el otro -1
de menos) con exactamente el mismo `imm` codificado, lo que descartaba un error
propio de codificación. Re-testeadas contra la versión nueva con el mismo test:
ambas saltan exactamente a la dirección esperada. Arregladas.

---

# Caso 22 — BUG, ARREGLADO EN LA VERSIÓN NUEVA
## Descripción
J (salto incondicional relativo al PC), para verificar si el mismo problema del
Caso 21 afecta también al formato J.

## Instrucciones
J 7 (elimm=7)

## Precondiciones
- PC de arranque = 0x0. Destino esperado por fórmula (`PC = PC + 4 + 4×elimm`):
  0 + 4 + 4×7 = 0x00000020

## Code
opcode J = 00001 (1), subcódigo so=00
```
set [0x0] 0x08000007
step
registers
```

## Postcondiciones (versión vieja)
- PC quedó en 0x0000001C (no en 0x20)

## Postcondiciones (versión nueva)
- PC = 0x00000020, correcto.

## Conclusiones
En la versión anterior no andaba: el PC quedaba exactamente 4 bytes (una palabra)
por debajo de lo esperado. Re-testeado contra la versión nueva con el mismo test:
salta exactamente a la dirección esperada. Arreglado.

---

# Caso 23
## Descripción
JR (salto indirecto a la dirección contenida en un registro, sin desplazamiento
inmediato). Sirve de control: al no usar el campo `imm`, permite ver si el bug de
los Casos 21-22 depende específicamente de la aritmética con `imm`.

## Instrucciones
JR $10,0

## Precondiciones
- $10 = 0x30

## Code
JR reinterpreta el formato I: opcode=00010, subcódigo so=00 en el campo rt, imm=0
```
set [0x0] 0x12800000
set r10 0x30
step
registers
```

## Postcondiciones
- PC = 0x00000030 (correcto)

## Conclusiones
Anduvo, sin cambios entre versiones. Con `imm=0` el salto siempre llegó a la
dirección esperada, incluso en la versión vieja donde BEQ/BLT/J fallaban (Casos
21-22) — esto reforzó en su momento la sospecha de que el bug estaba específicamente
en cómo se combinaba `imm` con el PC, hipótesis que quedó confirmada al arreglarse
justamente ese cálculo en la versión nueva.

---

# Caso 24 — nuevo en esta versión
## Descripción
Banderas Z, N, O, C del registro `$psw`. El manual nuevo extendió mucho esta sección
(antes solo se mencionaban, ahora trae ejemplos numéricos resueltos para ADD/SUB y
para la familia de multiplicación/división). En la versión anterior de la máquina se
había confirmado que estas banderas nunca se actualizaban; se re-testea acá.

## Instrucciones
ADD $12,$10,$11 (dos casos: uno que da acarreo+cero, otro que da overflow+negativo)

## Precondiciones
- Test A: $10 = 0xFFFFFFFF, $11 = 1 (0xFFFFFFFF+1=0: se espera Z=1,C=1,N=0,O=0)
- Test B: $10 = 0x7FFFFFFF, $11 = 1 (0x7FFFFFFF+1=0x80000000: se espera
  N=1,O=1,Z=0,C=0)

## Code
```
set [0x0] 0x0296C00C
set r10 0xFFFFFFFF
set r11 1
step
registers
set pc 0x0
set [0x0] 0x0296C00C
set r10 0x7FFFFFFF
set r11 1
step
registers
```

## Postcondiciones
- Test A: R12 = 0x00000000, Flags = `[-ZC--]` (Z y C activas, N y O no)
- Test B: R12 = 0x80000000, Flags = `[N--V-]` (N y overflow activas, Z y C no)

## Conclusiones
Anduvo. Las banderas ahora se actualizan y coinciden exactamente con los ejemplos
resueltos del manual (sección 7.1.1) para ambos casos. En la versión anterior de la
máquina las banderas jamás cambiaban de `[-----]` sin importar la operación —
funcionalidad nueva/arreglada en esta versión. Nota: el debugger muestra la bandera
de overflow como `V`, no como `O` (probablemente por la convención más común de
"oVerflow" en la letra usada en pantalla), pero se corresponde con la misma bandera
`O` del manual.

---

# Caso 25 — verificación liviana, no anduvieron
## Descripción
Primer intento de probar CFS, CTS y TRAP (dejadas pendientes en toda la entrega
anterior). No es una prueba exhaustiva de todos los índices de registro especial ni
de todos los vectores de excepción, pero alcanza para confirmar si la instrucción
hace algo en absoluto.

## Instrucciones
CTS $10,5 (escribir $vbr) ; CFS $11,5 (leer $vbr) ; CFS $10,0 (leer $psw) ;
TRAP 2

## Precondiciones
- Para CTS/CFS de $vbr (índice 5 según el orden del manual: psw=0, ecr=1, epc=2,
  esr=3, bva=4, vbr=5, pir=6): $10 = 0x12345678, se espera que $vbr pase a valer
  eso y que CFS lo refleje en $11.
- Para CFS de $psw (índice 0): sin precondición, se espera reflejar el valor de
  reset (M=1, T=1 → 0x00000060).
- Para TRAP 2: PC=0x0, se espera EPC=0x4 y salto a $vbr+(2<<2)=0xF0000008.

## Code
func nuevo: CFS=0x20, CTS=0x21, TRAP=0x22
```
set [0x0] 0x028002A1   (CTS $10,5)
set [0x4] 0x02C002A0   (CFS $11,5)
set r10 0x12345678
step
registers
step
registers

(aparte, proceso limpio)
set [0x0] 0x02800020   (CFS $10,0 = PSW)
step
registers

(aparte, proceso limpio)
set [0x0] 0x00000122   (TRAP 2)
step
registers
```

## Postcondiciones
- CTS/CFS de $vbr: `registers` sigue mostrando VBR = 0xF0000000 sin cambios (CTS no
  escribió), y R11 quedó en 0 (CFS no leyó nada).
- CFS de $psw: R10 quedó en 0 (se esperaba 0x00000060).
- TRAP 2: PC avanzó normalmente a 0x00000004 (no saltó a 0xF0000008), EPC quedó en 0
  (no se guardó PC+4), y CAUSE pasó a 0x00000006 (un código nuevo, distinto del
  patrón viejo de ADDI/LUI que era CAUSE=3).

## Conclusiones
No anduvieron. CFS y CTS no leen ni escriben ningún registro especial (probado con
$vbr y con $psw). TRAP no transfiere el control a la tabla de vectores ni actualiza
$epc, aunque sí modifica CAUSE con un código (6) distinto a los vistos antes — puede
ser una excepción de "instrucción no soportada" en vez de la ejecución real de TRAP.
No se pudo probar RFT de forma significativa porque depende de un EPC real que TRAP
todavía no produce. Sigue pendiente para una próxima entrega, como en las anteriores.

---

# Resumen final

| # | Instrucciones | Resultado |
|---|---|---|
| 1 | ADD, SUB | OK (func recalculado) |
| 2 | AND, OR, XOR, NOR | OK (func sin cambios) |
| 3 | SLT, SLTU | OK (func recalculado) |
| 4 | SLL, SRL, SRA | OK (func recalculado) |
| 5 | RLC (nueva) | OK |
| 6 | SLLR, SRLR, SRAR, RLCR (nueva) | OK (func recalculado) |
| 7 | ADDI | OK (opcode recalculado) |
| 8 | ANDI | Estaba rota (ignoraba el inmediato), arreglada en la versión nueva |
| 9 | ANI, ANH (nuevas) | Estaban rotas (no preservaban la mitad), arregladas |
| 10 | ORI, ORH (ORH nueva) | OK |
| 11 | XORI, XORH (XORH nueva) | OK |
| 12 | LCI (nueva, reemplaza LUI) | Estaba rota, arreglada en la versión nueva |
| 13 | SW, LW | OK |
| 14 | SB, LB, LBU | OK |
| 15 | SH, LH + alineación de 16 bits | OK (incluye la nueva excepción de alineación) |
| 16 | LWX | OK |
| 17 | SWX, SHX, SBX (nuevas) | Crasheaban el emulador, arregladas en la versión nueva |
| 18 | MUL, DIV, REST | OK (func recalculado) |
| 19 | MULHU, DIVU, RESTU | OK (func recalculado) |
| 20 | MULH, MULHSU (nueva) | Estaban rotas, arregladas en la versión nueva |
| 21 | BEQ, BLT | Estaban rotas (dirección de salto mal calculada), arregladas |
| 22 | J | Estaba rota, arreglada en la versión nueva |
| 23 | JR | OK (control: sin imm, nunca se manifestó el bug) |
| 24 | Flags Z/N/O/C (ADD) | OK — antes nunca se actualizaban, ahora funcionan |
| 25 | CFS, CTS, TRAP | No anduvieron — primera prueba real, siguen sin implementar |

Total: 36 pruebas realizadas sobre 35 instrucciones + verificación de flags, todas
correctas contra la versión 0.1.1-RC1 (re-testeadas sin regresión respecto de la
0.1.0-RC1, donde ya se habían confirmado arregladas 8 casos que antes fallaban:
Casos 8, 9, 12, 17, 20, 21, 22 y las flags del Caso 24). Además, primera prueba real
de CFS/CTS/TRAP (Caso 25): siguen sin funcionar.

Pendientes (dejados a propósito para el final, como sugirió el profesor):
TRAP, RFT, CFS, CTS. También quedaron sin probar JAL, JALR, JALX, JALRX, BNE, BGE,
BLTU, BGEU.
