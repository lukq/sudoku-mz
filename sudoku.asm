; Program to play sudoku on CP/M
; by Lukas Petru, February 2018
; compiled: 480 bytes + data

; Open source under the MIT License (Expat).

bdos .equ 5
charout .equ 2
strout .equ 9

kright .equ 4 ; keys
kleft .equ 19
kup .equ 5
kdown .equ 24
kclr .equ 7

size .equ 81         ; one puzzle size in bytes
testbuffer .equ 5    ; high byte of test buffer
puzzleaddr .equ 600h ; unpacked data go here

  .org 100h
  ;unpack
  ld de,puzzleaddr+size+10  ; address of row 1 column 1
  ld hl,templ0    ; packed data start
uloop:
  ld a,(hl)
  rrca
  rrca
  rrca
  rrca
  and 15
  cp 10           ; decode high nibble
  jr c,$+5        ; if num=0ah
  sub a           ; set to 0
  ld (de),a
  inc de

  ld (de),a       ; may be repeated
  inc de

  ld a,(hl)
  inc hl
  ld (de),a       ; copy low nibble
  inc de
  bit 2,h
  jr z,uloop      ; while data left


  ; skip puzzles
  ld de,strstart
  call prints

  call waitkey
  sub '2'
  jr c,start

  inc a
  ld b,a
pskip:
  call nextlvl
  ret z
  djnz pskip


  ; start game
start:
  ld a,26         ; cls
  call printc
printgrid:
  ld c,-3         ; b=0-9
  sub a
  call gotoxy     ; position for grid top left
  call nl         ; tab


  ld hl,grid
  ld c,7          ; grid has 7 segments
lgrid:
  ld e,gridrow
  ld b,3          ; 3 empty rows
  bit 0,c
  jr z,printrow   ; print them
  ld e,(hl)
  inc hl
  ld b,1

printrow:
  ld d,gridrow/256
  push bc
  push de

  ld c,7          ; row has 7 segments
rowloop:
  ld a,(de)       ; read segment char
  ld b,1          ; segment length=1
  bit 0,c
  jr nz,printchar ; print single char

  inc de          ; filler char
  cp 83h          ; 82 - vertical line
  ld a,81h        ; 81 - horizontal line
  sbc a,0         ; 80 - empty
  ld b,5          ; segment length=5
printchar:
  call printc
  djnz printchar  ; repeat char

  dec c
  jr nz,rowloop

  call nl
  pop de
  pop bc
  djnz printrow


  dec c
  jr nz,lgrid


  ; fill numbers from template into screen
fillin:
  ld c,9         ; 9 rows
fillr:
  ld b,9         ; 9 columns
fillc:
  call istempl
  and 15         ; clear high nibble
  ld (hl),a      ; clear user entry
  jr z,contf
  or 30h         ; char from template
  call gotoxy    ; print
contf:
  djnz fillc

  dec c
  jr nz,fillr


  ; wait for keypress
  inc b
  inc c          ; b=c=1
kloop:
  sub a
  call gotoxy
  exx
  call waitkey
  exx

  cp 3
  ret z          ; ^c exit

  cp kclr
  jr z,printgrid

  cp 32
  jr nc,kput

  dec c
  cp kup
  jr z,kmovey
  inc c
  inc c
  cp kdown
  jr z,kmovey
  dec c
  dec b
  cp kleft
  jr z,kmovex
  inc b
  inc b

kmovex:
  ld a,b
  call wrap
  ld b,a
kmovey:
  ld a,c
  call wrap
  ld c,a
jkloop:
  jr kloop

kput:
  ; put char into cell
  ex af,af'
  call istempl
  or a
  jr nz,kloop     ; cannot write here

  ex af,af'
  call printc
  or 0b0h
  ld (hl),a       ; store user input


  ; test grid
  exx
  ld hl,testbuffer*256
  sub a
  ld (hl),a
  dec l
  jr nz,$-2

  ld c,9
trow:
  ld b,9
tcol:
  call gettempl
  and 15
  jr z,contt

  ld d,a
  rlca
  rlca
  rlca
  add a,d
  ld d,a
  add a,b
  ld h,testbuffer
  ld l,a
  inc (hl)

  ld a,c
  add a,81
  add a,d
  ld l,a
  inc (hl)

  ld e,162-3
  ld a,b
  dec a
  inc e
  inc e
  inc e
  sub 3
  jr nc,$-5
  ld a,c
  dec a
  inc e
  sub 3
  jr nc,$-3
  ld a,e
  add a,d
  ld l,a
  inc (hl)

contt:
  djnz tcol
  dec c
  jr nz,trow

  ld c,243
  ld l,10
  sub a
  cpir
  exx
  jr z,jkloop

  ; solved
  ld hl,solved
  inc (hl)          ; solved puzzles count
  ld b,(hl)
  ld c,-3           ; above grid
  ld a,0b7h         ; heart
  call gotoxy

  call nextlvl
  jp nz,printgrid   ; loop if there are more puzzles

  ld c,10           ; move cursor down
  sub a
  jr gotoxy         ; and exit


waitkey:
  ld c,6
  ld e,255
  call bdos
  or a
  jr z,waitkey
  ret

nextlvl:
  ld hl,(templ)
  ld de,-size
  add hl,de
  ld (templ),hl
  ld a,l
  or a
  ret

istempl:
  call gettempl ; get current value
  cp 0b0h     ; if lower than b0
  ret c       ;  it is a template number
  sub a       ; else it's user input
  ret         ;  set to 0

gettempl:
  ld a,c
  rlca
  rlca
  rlca
  add a,c
  add a,b
  ld d,0
  ld e,a       ; c*9+b
  ld hl,(templ)
  add hl,de
  ld a,(hl)    ; read template number
  ret


wrap:
  or a
  jr nz,$+4
  ld a,9
  cp 10
  jr nz,$+4
  ld a,1
  ret


gotoxy:
  push bc
  exx
  pop bc
  ld de,poscmd+4 ; load cursor command buffer
  ld (de),a
  dec de

  ld a,b         ; x
  add a,a
  add a,2fh
  ld (de),a
  dec de
  ld a,c         ; y
  cp 4
  sbc a,0        ; first grid divider
  cp 7
  sbc a,0        ; second grid divider
  add a,26h
  ld (de),a

  ld de,poscmd
prints:
  ld c,strout
  call bdos
  exx
  ret


nl:     ; print nl and 2xtab
  ld a,14
  dec a
  call printc
  cp 9
  jr nz,nl+2
  call printc
  ret
  
printc:
  exx
  push af
  ld c,charout
  ld e,a
  call bdos
  pop af
  exx
  ret

grid:
.db gridtop,gridmid,gridmid,gridbot
gridtop:
.db 87h,8ah,8ah,86h
gridrow:
.db 82h,82h,82h,82h
gridmid:
.db 8bh,83h,83h,89h
gridbot:
.db 84h,88h,88h,85h

poscmd:
.db 27,"=   $"

solved:
.db 0

strstart:
.db "Start from puzzle 1-"

; will be filled in by the generator
.db "2?$"

templ:
.dw 2*size+puzzleaddr ; last sudoku data

; packed data
templ0:
.db 03h,0a0h,06h,0a9h
.db 0a0h,48h,03h,05h
.db 81h,0a0h,0a2h,0a0h
.db 02h,10h,94h,0a0h
.db 03h,0a0h,02h,40h
.db 86h,0a0h,06h,0a0h
.db 0a4h,21h,09h,06h
.db 80h,50h,0a0h,50h
.db 0a0h,60h,80h,0a1h
.db 0a0h,90h,50h,80h
.db 70h,10h,0a4h,09h
.db 07h,0a0h,60h,70h
.db 10h,20h,50h,80h
.db 60h,10h,70h,10h
.db 50h,20h,90h,0a7h
.db 04h,06h,0a0h,80h
.db 30h,90h,40h,30h
.db 0a5h,0a0h,80h
