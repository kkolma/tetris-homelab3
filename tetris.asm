; TETRIS clone for the Z80 based HomeLab 3/4 microcomputers
; HU: TETRIS klón HomeLab 3-4 gépekre
; 
; Coded by: Kornél Kolma (Ko-Ko), 2024. 
; Pleasurebytes Games |PEXY.io | No Man's Bytes | 
; e-mail: kolma.kornel@gmail.com
; 
; This game was made for the second programming contest of the HomeLab Computers.  
; Sorry guys, the comments were written in Hungarian but labels, constants and function names are in English.


org 0x4100

SCREENMEM:		EQU	0xf800
;BUFFER:		EQU	0x6000		;buffer kuka, hl3 nem bírja

;SCORETEXT:		EQU SCREENMEM + 5*64+6
SCOREVALUE:		EQU SCREENMEM + 5*64+14

RECORDTEXT:		EQU	SCREENMEM + 8*64+9
HISCOREVALUE:	EQU SCREENMEM + 9*64+14

LEVELTEXT:		EQU SCREENMEM + 11*64+9
LEVELHI:		EQU	SCREENMEM + 13*64+14
LEVELLOW:		EQU SCREENMEM + 13*64+15
CAGE:			EQU SCREENMEM + 5*64+30

NEXTTEXT:		EQU SCREENMEM + 5*64+50
NEXTBLOCK:		EQU SCREENMEM + 5*64+52

PEXYLOGO:		EQU SCREENMEM + 64*19+28

RLOC:			EQU	SCREENMEM + 5*64+32

KSZ:			EQU 0x00f6		;képszinkront levárja (sic!) :-)

init:
	out ($ff),a				; <- Memória lapozás / köszi Nickmann Laci
	ld sp,$40FF
	call clearScreen
	call printTitleScreen
	ld a,0
	ld 	(rcounter),a		;reset R spinner
	ld (rdir),a
	call waitNoEnter
	ld hl,titletimer
	ld (hl),0
	ld hl,titletimer2
	ld (hl),0
titleloop:
	ld hl, titletimer
	inc (hl)
	call slowDown
;call titleScroll
	call slowDown
	call titleFirework
	call titleSpineR
	;call KSZ
	ld hl,0xe801	
	ld a,(hl)
	bit 1,a
	jp nz,titleloop
	
	ld a,r 						;a random "generátor" seedelése
	ld (rindex),a

initgame:
	call clearScreen
	;call clearBuffer
	call copyGameScreen

;call drawCage

	call initBeforeGamesVariables
	call rand7bag
	ld hl, gameoverflag
	ld (hl),0
	ld a,(tmodeLow)
	ld (timerLow), a
	ld a,(tmodeHi)
	ld (timerHi), a

	call displayScore
	call displayHighScore
	call generateBlock
	call printLevel
	call printBlock
	;call printInGameText
	call printPromo
gameLoop:
	call keyboardCheck
	;call slowDown
	call fallBlock
	ld a, (gameoverflag)
	cp 1
	jp nz, gameLoop

	call printGameOverText
	call makeGameOverSound

	call waitEnter
	jp init

;######## TITLE effektek
titleFirework:
	ld a,(titletimer)
	cp  $74
	jp z,startsecondtimer
	ret
startsecondtimer:
	ld hl,titletimer2
	inc (hl)
	ld a,(hl)
	cp $3
	jp z,gotofirework
	ret
gotofirework:
	ld a,0
	ld (hl),a
	ld hl,SCREENMEM+15*64	;innentől van tűzijáték
	ld bc,450 				;ennyi sort néz meg
makeFirework:
	ld a,(hl)
	cp $2e					;'pont'
	jp nz,nodot
	ld a,$2b
	ld (hl),a
	jp thisoneisready
nodot:
	cp $2b					;plusz
	jp nz,noromboid
	ld a,$2a
	ld (hl),a
	jp thisoneisready
noromboid:
	cp $2a					;'*'
	jp nz,nostar
	ld a,$2e
	ld (hl),a
	jp thisoneisready
nostar:
thisoneisready:
	inc hl
	dec bc
	ld a,b
	or c
	jp nz,makeFirework
	ret
	
titleSpineR:
	ld a,(titletimer)
	cp $74
	jp z,checkRtimer
	ret
checkRtimer:
	ld hl,rcounter
	inc (hl)
	ld a,(hl)
	cp 20
	jp z,dospiner
	ret
dospiner:
	ld hl,rdir				;0 fordított R, 1 - köztes állapot 'I', 2 - normál R
	inc (hl)
	ld a,(hl)
	cp 0
	jp z,reverseR
	cp 1
	jp z,middleR
	cp 2
	jp z,normalR
	cp 3
	jp z,middleR
	ret
reverseR:
	ld a,0
	ld (rcounter),a
	ld hl,r1
	call copyR
	ret
middleR:
	cp 3
	jp nz,nonullR
	ld a,$ff			;mert inc van 'utána'
	ld (rdir),a
nonullR:
	ld a,19
	ld (rcounter),a
	ld hl,r2
	call copyR
	ret
normalR:
	ld a,0
	ld (rcounter),a
	ld hl,r3
	call copyR
	ret

copyR:
	ld de,RLOC
	ld bc,0
simplefivelinecopy:
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	inc c
	inc b
	ld a,c
	cp 6
	jp nz,nonextline
	ld c,0
	push bc
	push hl
	ld bc,58
	ld hl,de
	add hl,bc
	ld de,hl
	pop hl
	pop bc
nonextline:
	ld a,b
	cp 48
	jp nz,simplefivelinecopy
	ret
	
	



;#### lassító rutin
slowDown:					 ;egyszerű lassító rutin 2 ciklusban
    ld b,0x01					 ;0 -> 256 ciklus
slower2: 
	ld c,b
	ld b,10
slower1:
	nop
    djnz slower1
    ld b,c
    djnz slower2
	ret

fallTimer:
	ld a,0
	ld hl,timerLow
	dec (hl)
	ld b,(hl)
	cmp b
	jp nz,stillCounting
	ld hl,level
	ld e,(hl)
	ld d,0
	ld a,(fastfall)
	cp 1
	jp nz,noFastFall1
	ld de,0
noFastFall1:
	ld hl,tmodeLow
	add hl,de
	ld a,(hl)
	ld (timerLow),a
	
	ld hl,timerHi
	dec (hl)
	ld b,(hl)
	ld a,0
	cmp b
	jp nz,stillCounting
	ld hl,level
	ld e,(hl)
	ld d,0
	ld a,(fastfall)
	cp 1
	jp nz,noFastFall2
	ld de,0
noFastFall2:
	ld hl,tmodeHi
	add hl,de
	ld a,(hl)
	ld (timerHi),a
	ld a,1
stillCounting:
	ret


updateLevel:
	ld a,(linecounter) ;10 soronként levelup
	cp 10
	jp nz,nolevelup
	ld a,0
	ld (linecounter),a
	ld a,(level)
	cp 19				;max 19 level
	jp z,nolevelup
	ld hl,level
	inc (hl)
	ld hl,LEVELLOW
	inc (hl)
	ld a,(hl)
	cp $3a
	jp nz,nonineinlevellow
	ld a,$30
	ld (hl),a
	ld hl,LEVELHI
	inc (hl)
nonineinlevellow:	
nolevelup:
	ret




checkLine:				;rekurzív rutin, ami ellenőrzi, hogy van-e teli sor
	ld a,0
	ld (linecount),a
clAgain:
	ld de,CAGE
	inc de
	
	ld b,0
checkAllLine:
	ld c,0
	ld hl,de
checkOneLine:
	ld a,(hl)
	cp $20				;van-e space az adott sorban?
	jp z,thisSpace
	inc hl
	inc c
	ld a,c
	cp 10
	jp nz,checkOneLine
	ld hl,linecount
	inc (hl)
	ld hl,linecounter
	inc (hl)
	call updateLevel
	push bc					;hl = de - 1 sor
	ld hl,de
	scf
	ccf
	ld bc,64
	sbc hl,bc
	pop bc
copyalllines:
	push hl
	ld c,0
copyOneLine:
	ld a,(hl)
	ld (de),a
	inc de
	inc hl
	inc c
	ld a,c
	cp 10
	jp nz,copyOneLine
	pop hl
	
	push bc
	ld de,hl				;hl és de mínusz 1-sor
	scf
	ccf
	ld bc,64
	sbc hl,bc	
	pop bc

	dec b
	ld a,b
	cp 0
	jp nz,copyalllines
	jp clAgain
thisSpace:
	ld hl,de
	ld de,64
	add hl,de
	ld de,hl
	inc b
	ld a,b
	cp 20
	jp nz,checkAllLine
	ld a,(linecount)
	cp 0
	jp z,zeroScore
	jp calcScore
zeroScore:
	ret
calcScore:

	ld c,10			;1 hangjegy lejátszása	
	ld a,115
	call 0x18e1

    ld a,(linecount)   
    dec a               
    ld c,a   
	ld b,0
	ld de,scorethis
	
    ld hl,scr1         
    add hl,bc          
    ld a,(hl)          
    ld (de),a
	
	inc de
    ld hl,scr2    
    add hl,bc
    ld a,(hl)
    ld (de),a

	inc de
    ld hl,scr3
    add hl,bc
    ld a,(hl)
    ld (de),a

	
	scf
	ccf
	ld hl,score
	ld de,scorethis
	
    ld a,(hl)
	ld b,(de)
    adc b
    daa
    ld (hl), a

	inc hl
	inc de
    ld a,(hl)
	ld b,(de)
    adc b
    daa
    ld (hl), a

	inc hl
	inc de
    ld a,(hl)
	ld b,(de)
    adc b
    daa
    ld (hl), a

	inc hl
	inc de
    ld a,(hl)
	ld b,(de)
    adc b
    daa
    ld (hl), a	
    call displayScore
	call checkHighScore
    ret


checkHighScore:					;csekkoljuk, hogy a jelenlegi pont > mint a hiscore
	ld ix,score
	ld iy,hiscore

    ld a, (ix+3)
    cp (iy+3)
    jr c, noUpdate
    jr nz, copyScoreIfGreater

    ld a, (ix+2)
    cp (iy+2)
    jr c, noUpdate
    jr nz, copyScoreIfGreater

    ld a, (ix+1)
    cp (iy+1)
    jr c, noUpdate
    jr nz, copyScoreIfGreater

    ld a, (ix)
    cp (iy)
    jr c, noUpdate
	
copyScoreIfGreater:
    ld hl, score
    ld de, hiscore
    ld bc, 4        
    ldir    
	call displayHighScore
noUpdate:
    ret


displayScore:
	ld de,SCOREVALUE
	ld c,3
	ld b,0
printScr:
	ld hl,score
	add hl,bc
    ld a,(hl) 
	push af
	srl a
	srl a
	srl a
	srl a
	add $30
	ld (de),a
	inc de
	pop af
	and $0f
	add $30
	ld (de),a
	inc de
	dec c
	ld a,c
	cp $ff
	jp nz, printScr
	ret

displayHighScore:
	ld de,HISCOREVALUE
	ld c,3
	ld b,0
printHiScr:
	ld hl,hiscore
	add hl,bc
    ld a,(hl) 
	push af
	srl a
	srl a
	srl a
	srl a
	add $30
	ld (de),a
	inc de
	pop af
	and $0f
	add $30
	ld (de),a
	inc de
	dec c
	ld a,c
	cp $ff
	jp nz, printHiScr
	ret


printLevel:
	ld a,$31
	ld hl,LEVELLOW
	ld (hl),a
	ld a,$30
	ld hl,LEVELHI
	ld (hl),a
	ret
	
	
	
	

fallBlock:
	call fallTimer
	cp  1
	jp nz,doNotFall	
	call eraseBlock
	ld hl,crY
	inc (hl)
	call checkBlock
	cp 1
	jp nz,stillFalling
	ld hl,crY
	dec (hl)
	call printBlock
	call checkLine
	call generateBlock
	ret
stillFalling:
	call printBlock
	;jsr copyBuffer
doNotFall:
	ret

keyboardCheck: ;jkl + space + as

	ld hl,0xe800			;crsr balra
	ld a,(hl)
	bit 3,a
	jp nz,noJpressed
	ld a,(isjpressed)
	cp 1
	jp z,Jpressedagain
	ld a,1
	ld (isjpressed),a
	
	call eraseBlock
	ld hl,crX
	dec (hl)
	call checkBlock
	cp 1
	jp nz,noCollJ
	ld hl,crX
	inc (hl)
noCollJ:
	call printBlock
	
	jp Jpressedagain
noJpressed:
	ld a,0
	ld (isjpressed),a
Jpressedagain:

	ld hl,$e800				;crsr jobbra
	ld a,(hl)
	bit 2,a
	jp nz,noLpressed
	ld a,(islpressed)
	cp 1
	jp z,Lpressedagain
	ld a,1
	ld (islpressed),a
	
	call eraseBlock
	ld hl,crX
	inc (hl)
	call checkBlock
	cp 1
	jp nz,noCollL
	ld hl,crX
	dec (hl)
noCollL:
	call printBlock
	
	jp Lpressedagain
noLpressed:
	ld a,0
	ld (islpressed),a
Lpressedagain:


	ld hl,$e800				;crsr LE (korábban K)
	ld a,(hl)
	bit 0,a
	jp nz,noKpressed		; itt nem kell az echoblock rutin
	ld a,(iskpressed)
	cp 133
	jp nz,Kpressedagain
	ld a,0
	ld (iskpressed),a
	
	ld a,1
	ld (timerLow),a
	ld a,1
	ld (timerHi),a
	
	jp noKpressed

Kpressedagain:
	ld a, (iskpressed)
	inc a
	ld (iskpressed),a

noKpressed:
	ld hl,$e808				;A
	ld a,(hl)
	bit 1,a
	jp nz,noApressed
	ld a,(isapressed)
	cp 1
	jp z,Apressedagain
	ld a,1
	ld (isapressed),a
	
	call eraseBlock
	ld a,(crFrame)		;save current frame before collusion detection
	ld (crTemp),a
	ld hl,crBlock
	ld e,(hl)
	ld d,0
	ld hl,blStart
	add hl,de
	ld a,(crFrame)
	ld c,a
	ld a,(hl)
	cp c
	jp z,minFrame
	ld hl,crFrame
	dec (hl)
	dec (hl)
	jp nominFrame
minFrame:
	ld hl,crBlock
	ld e,(hl)
	ld d,0
	ld hl,blEnd
	add hl,de
	ld a,(hl)
	ld (crFrame),a
nominFrame:
	call checkBlock
	cp 1
	jp nz,noCollA
	ld a,(crTemp)
	ld (crFrame),a
noCollA:
	call printBlock
	jp Apressedagain
noApressed:
	ld a,0
	ld (isapressed),a
Apressedagain:

	ld hl,$e800			   ;crsr up = s -> forgatas, csak a joy miatt
	ld a,(hl)
	bit 1,a
	jp nz,noUpCRSRpressed
	jp forgatas

noUpCRSRpressed:
	ld hl,$e80d				;S
	ld a,(hl)
	bit 3,a
	jp nz,noSpressed
forgatas:
	ld a,(isspressed)
	cp 1
	jp z,Spressedagain
	ld a,1
	ld (isspressed),a
	
	call eraseBlock
	ld a,(crFrame)		;save current frame before collusion detection
	ld (crTemp),a
	ld hl,crBlock
	ld e,(hl)
	ld d,0
	ld hl,blEnd
	add hl,de
	ld a,(crFrame)
	ld c,a
	ld a,(hl)
	cp c
	jp z,maxFrame
	ld hl,crFrame
	inc (hl)
	inc (hl)
	jp nomaxFrame
maxFrame:
	ld hl,crBlock
	ld e,(hl)
	ld d,0
	ld hl,blStart
	add hl,de
	ld a,(hl)
	ld (crFrame),a
nomaxFrame:
	call checkBlock
	cp 1
	jp nz,noCollS
	ld a,(crTemp)
	ld (crFrame),a
noCollS:
	call printBlock
		
	jp Spressedagain
noSpressed:
	ld a,0
	ld (isspressed),a
Spressedagain:


	ld hl,$e801				;SPACE
	ld a,(hl)
	bit 0,a
	jp nz,noSPCpressed
	ld a,(isspacepressed)
	cp 1
	jp z,SPCpressedagain
	ld a,1
	ld (isspacepressed),a
	
	ld a,1
	ld (fastfall),a
	ld (timerLow),a
	
	jp SPCpressedagain
noSPCpressed:
	ld a,0
	ld (isspacepressed),a
SPCpressedagain:


	ret

	


printblocknow:				;kirajzolja az aktuális blokkot
	ld hl,crY
	ld a,(hl)
	ld hl,crX
	ld l,(hl)
	ld h,0
	ld b,a
	cp 0
	jp z, readyCYpbn
	ld de,64
calcpbY:
	add hl,de
	djnz calcpbY
readyCYpbn:					
	ld de,hl				;de-ben az x,y képernyő pozi offset nélkül
	ld hl,SCREENMEM
	add hl,de				;hl-ben a current block pozi


	push hl
	ld hl,crFrame			
	ld e,(hl)
	ld d,0
	ld hl,frLoHi
	add hl,de
	ld de,(hl)				;de-ben az aktuális blokkframe
	pop hl
	ld b,16
	ld c,0
printPBnow:
	ld a,(de)
	cp $20					;blockban 'space'
	jp z,skipSpace
	ld a,(ghostblockflag)
	cp 1
	jp nz,noghostblockprint
	ld a,$02				;ghost block karakter
	jp avoidprintnormalblockchar
noghostblockprint:
	ld a,(de)				;lehetne akár a blokkchar is
avoidprintnormalblockchar:
	ld (hl),a
skipSpace:
	inc hl
	inc de
	inc c
	ld a,c
	cp 4
	jp nz,nonextrawPBN
	ld c,0
	push de
	ld de,60				;kövi sorocska bufferben
	add hl,de			
	pop de	
nonextrawPBN:
	djnz printPBnow
	ret


printBlock:
	ld a,(crY)
	ld (crYtemp),a
	
	ld a,(newblockflag)
	cp 1
	jp z,newblockiscomingpb
stillnotthebottom:
	ld hl,crY
	inc (hl)
	call checkBlock
	cp 1
	jp nz,stillnotthebottom
	ld hl,crY
	dec (hl)
	ld a,(crY)
	ld (crYGhost),a
	ld a,1
	ld (ghostblockflag),a
	call printblocknow
	ld a,(crYtemp)
	ld (crY),a
newblockiscomingpb:
	ld a,0
	ld (ghostblockflag),a
	call printblocknow
	;call copyBuffer
	ret


eraseBlock:
	ld a,(crY)
	ld (crYtemp),a
	ld a,0
	ld (ghostblockflag),a
	call eraseblocknow
	ld a,(crYGhost)
	ld (crY),a
	ld a,(newblockflag)
	cp 1
	jp z,newblockiscoming
	ld a,1
	ld (ghostblockflag),a
	call eraseblocknow
newblockiscoming:
	ld a,0
	ld (newblockflag),a
	ld a,(crYtemp)
	ld (crY),a
	ret

eraseblocknow:					
	ld hl,crY
	ld a,(hl)
	ld hl,crX
	ld l,(hl)
	ld h,0
	ld b,a
	cp 0
	jp z, readyCYebn
	ld de,64
calcebY:
	add hl,de
	djnz calcebY
readyCYebn:					
	ld de,hl				;de-ben az x,y képernyő pozi offset nélkül
	ld hl,SCREENMEM
	add hl,de				;hl-ben a current block pozi
	
	push hl
	ld hl,crFrame			
	ld e,(hl)
	ld d,0
	ld hl,frLoHi
	add hl,de
	ld de,(hl)				;de-ben az aktuális blokkframe
	pop hl
	ld b,16
	ld c,0
eraseblnow:
	ld a,(de)
	cp $20					;blockban 'space'
	jp z,skipEraseSpace
	ld  a,$20
	ld (hl),a
skipEraseSpace:
	inc hl
	inc de
	inc c
	ld a,c
	cp 4
	jp nz,nonextrawEBN
	ld c,0
	push de
	ld de,60				;kövi sorocska bufferben
	add hl,de			
	pop de	
nonextrawEBN:
	djnz eraseblnow
	ret
	

printNextBlock:	
	ld hl,crBlocknext
	ld e,(hl)
	ld d,0
	ld hl,blStart
	add hl,de
	ld e,(hl)
	ld d,0
	ld hl,frLoHi
	add hl,de
	ld de,(hl)
	ld hl,de
	
	ld de,NEXTBLOCK	
	ld b,16			;1 block 4x4-es
	ld c,0
copyNB:
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	inc c
	ld a,c
	cp 4
	jp nz,nonextrawNB
	ld c,0
	push hl
	ld hl,60			;kövi sorocska
	add hl,de
	ld de,hl			
	pop hl	
nonextrawNB:
	djnz copyNB
	ret


checkBlock:				;ellenőrzi, hogy a blokk az adott poziba pakolható-e
	ld hl,crY			
	ld a,(hl)
	ld hl,crX
	ld l,(hl)
	ld h,0
	ld b,a
	cp 0
	jp z, readyCY
	ld de,64
calcPrintBlockY:
	add hl,de
	djnz calcPrintBlockY
readyCY:					
	ld de,hl				;de-ben az x,y képernyő pozi offset nélkül
	ld hl,SCREENMEM
	add hl,de				;hl-ben a current block pozi

	push hl
	ld hl,crFrame			
	ld e,(hl)
	ld d,0
	ld hl,frLoHi
	add hl,de
	ld de,(hl)				;de-ben az aktuális blokkframe
	pop hl
	ld b,16
	ld c,0
checkBlocknow:
	ld a,(de)
	cp $20					;blockban 'space'
	jp z,skipCheckSpace
	ld a,(hl)
	cp $20					;bufferben 'space'
	jp z,skipCheckSpace
	cp $76					;bufferben ghost block darabka
	jp z,skipCheckSpace
	ld a,1					;ez bizony ütközés
	ret
skipCheckSpace:
	inc hl
	inc de
	inc c
	ld a,c
	cp 4
	jp nz,nonextrawCB
	ld c,0
	push de
	ld de,60				;kövi sorocska bufferben
	add hl,de			
	pop de	
nonextrawCB:
	djnz checkBlocknow
	ld a,0					;nincs ütközés
	ret
	
	
	
generateBlock:
	ld a,1
	ld (newblockflag),a
	ld a,0
	ld (fastfall),a		;reset fast fall mód
	
	ld hl, bagindex
	ld e,(hl)
	ld d,0
	ld hl, sevenbag
	add hl,de
	ld a,(hl)
	ld (crBlock),a
	ld hl,bagindex
	inc (hl)
	ld a,(hl)
	cp 7
	jp nz,bagisnotempty
	ld a,0
	ld (hl),0
	call rand7bag
bagisnotempty:
	ld hl, bagindex
	ld e,(hl)
	ld d,0
	ld hl, sevenbag
	add hl,de
	ld a,(hl)
	ld (crBlocknext),a
	call printNextBlock
	ld hl,crBlock
	ld e,(hl)
	ld d,0
	ld hl,blStart
	add hl,de
	ld a,(hl)
	ld (crFrame),a
	ld a,34							; blokk start pozíció
	ld (crX),a
	ld a,3
	ld (crY),a
	call checkBlock
	cp 1
	jp nz,notLast
gameOver:
	ld (gameoverflag),a
notLast:
	ret

printGameOverText:				;ez csak teszt, majd rövidítem
	ld hl,gotext	
	ld de,SCREENMEM+11*64+29
	ld bc,14
	ldir
	
	ld de,SCREENMEM+12*64+29
	ld bc,14
	ldir

	ld de,SCREENMEM+13*64+29
	ld bc,14
	ldir	

	ld de,SCREENMEM+14*64+29
	ld bc,14
	ldir

	ld de,SCREENMEM+15*64+29
	ld bc,14
	ldir

	ld de,SCREENMEM+16*64+29
	ld bc,14
	ldir	

	ld de,SCREENMEM+17*64+29
	ld bc,14
	ldir	

	ld de,SCREENMEM+18*64+29
	ld bc,14
	ldir	
	ret
	
makeGameOverSound:
	ld a,20
	ld c,4
makegosound1:
	push af
	call 0x18e1
	pop af
	inc a
	inc a
	inc a
	inc a
	inc a
	cp 160
	jp nz, makegosound1
	ret



rand7bag: ; A sevenbag memóriaterületet feltöltjük 7 különböző, 0-6 közötti számmal
    call genrandom06 ; generáljunk egy 0-6 közötti, és azzal feltöltjük az egészet
	ld b,7
	ld hl,sevenbag
reset7bag:
	ld (hl),a
	inc hl
	djnz reset7bag
	
	ld de,sevenbag
	inc de			;7bag 2. pozíciótól nyitunk, mert az elsőben már van érték

	ld b,6
allbag:
	push b
itsaduplicate:
	ld b,7
	ld hl, sevenbag
	call genrandom06
checkduplicate:
	ld c,(hl)
	inc hl
	cp c
	jp z,itsaduplicate
	djnz checkduplicate
	
	ld (de),a
	inc de
	
	pop b
	djnz allbag
	
	ret
	


genrandom06:
	push hl
	push de
	ld hl, rindex
	ld a,(hl)
	cp 255
	jp nz, norndoverflow
	ld a,0
	ld (hl),a
norndoverflow:
	inc (hl)
	ld e,(hl)
	ld d,0
	ld hl,rnumbers
	add hl,de
	ld a,(hl)
	pop de
	pop hl
	ret
	



; "ketrec rajzolása" nem kell már. lásd. copyGameScreen függvény
; drawCage:
;     ld hl, CAGE            ; ide tegye
;     ld b, 20
;drawLR:
;     ld a, $ff              ; oldalfal karakter
;     ld (hl), a
;     push hl
;     ld de, 10
;     inc de
;     add hl, de
;     ld (hl), a
;     pop hl
;     ld a, l
;     add a, 64
;     ld l, a
;     jr nc, drnoCC
;     inc h
; drnoCC:
;     djnz drawLR
;
;     ld a,$ff				;alj karakter
;	 ld b,12
; drawBottom:
;     ld (hl), a
;     inc hl
; howdeep:
;     djnz drawBottom
;     ret


copyGameScreen:
	ld hl,gamescreen
	ld de,SCREENMEM
	ld bc,2048
	ldir
	ret





initBeforeGamesVariables:
    ld a,1
    ld (level), a
    xor a  ; az a regisztert nullára állítja
    ld (linecounter), a
	ld a,0
	ld hl,score
	ld b,4
resetScore:
	ld (hl),a
	inc hl
	djnz resetScore
    ret
	

; copyBuffer:
	; ld hl,BUFFER
	; ld de,SCREENMEM+12+3*64
	; ld bc,25
; loopocska111111:
	; push bc
	
	; ld bc, 40
	; ldir

    ; ld a, e   
    ; add a, 24 
    ; ld e, a   
    ; ld a, d   
    ; adc a, 0  
    ; ld d, a
	; pop bc
	; djnz loopocska111111	

	
	; ret

; clearBuffer:
	; ld a,0x20						;' '
	; ld hl,BUFFER
	; ld de,BUFFER+1
	; ld bc,1000
	; ld (hl),a
	; ldir
	; ret

clearScreen:
	ld a,0x20
	ld hl,SCREENMEM
	ld de,SCREENMEM+1
	ld bc,2048
	ld (hl),a
	ldir
	ret
	
waitEnter:
	ld hl,0xe801	
	ld a,(hl)
	bit 1,a
	jp nz,waitEnter
	ret

waitNoEnter:
	ld hl,0xe801	
	ld a,(hl)
	bit 1,a
	jp z,waitNoEnter
	ret

printTitleScreen:
	ld hl,titlescreen
	ld de,SCREENMEM+12+3*64
	ld b,27
cuccermasolo:
	push bc
	
	ld bc, 40
	ldir

    ld a, e   
    add a, 24 
    ld e, a   
    ld a, d   
    adc a, 0  
    ld d, a
	pop b
	djnz cuccermasolo

	ret

; printInGameText:
	; ; ld hl,pontszamtext
	; ; ld de,SCORETEXT
	; ; ld bc,9
	; ; ldir

	; ld hl,rekordtext
	; ld de,RECORDTEXT
	; ld bc,7
	; ldir

	; ld hl,szinttext
	; ld de,LEVELTEXT
	; ld bc,6
	; ldir
   
	; ld hl,kovetkezotext
	; ld de,NEXTTEXT
	; ld bc,9
	; ldir	
	; ret

printPromo:			
ret ;******			
	; ld hl,prlinelength			;copy pexy logo jobbra
	; inc hl
	; ld (hl),12
	; ld hl,prplus
	; inc hl
	; ld (hl),28
	; ld hl,prfulllength
	; inc hl
	; ld (hl),36
	; ld hl,pexylogo				
	; ld de,PEXYLOGO
	; ld bc,0
	; call cpPromo

	; ld hl,prlinelength			;copy PB logo balra
	; inc hl
	; ld (hl),14
	; ld hl,prplus
	; inc hl
	; ld (hl),26
	; ld hl,prfulllength
	; inc hl
	; ld (hl),112
	; ld hl,pblogo				
	; ld de,SCREENMEM+64*15
	; ld bc,0
	; call cpPromo
	
	
	
	ret

cpPromo:					;általános rutin bármilyen blokk kiiratása, de csak a kód módosításával működik (lásd. printPromo)
	ld a,(hl)
	ld (de),a
	inc hl
	inc de
	inc c
	inc b
	ld a,c
prlinelength:
	cp 12
	jp nz,nonextlinepromo
	ld c,0
	push bc
	push hl
prplus:
	ld bc,28
	ld hl,de
	add hl,bc
	ld de,hl
	pop hl
	pop bc
nonextlinepromo:
	ld a,b
prfulllength:
	cp 36
	jp nz,cpPromo
	ret
;******************EGYÉB*************************************



;******************TITLE EFFEKTEKHEZ KAPCSOLÓDÓ VÁLTOZÓK ****
titletimer:		db 0	;különböző értékeknél aktivizálódó effektek	
titletimer2:	db 0	;hi of lt1
;******************AKTUÁLIS BLOKK INFO********************

sevenbag:		db 0,1,2,3,4,5,6
bagindex:		db 0
crBlocknext:	db 0	;köv blokk
crBlock:		db 0	;jelenlegi blokk, lehetséges értékek: 0,1,3,4,5,6
crFrame:		db 0	;aktuális Frame, lehetséges értékek: 0-18
crX:			db 0
crY:			db 0
crTemp:			db 0  	;temp változó
crYtemp:		db 0
crYGhost:		db 0 	;ghost blokk Y
ghostblockflag: db 0
newblockflag:	db 0

;******************TETRIS JÁTÉK PARAMÉTEREK + EGYÉB *******************
nextblockright:	db	13	;következő elem pozíciója a képernyőn
gameoverflag:	db	0	;1 => gameover
isjpressed:		db	0
iskpressed:		db	0
islpressed:		db	0
isspacepressed:	db	0
isapressed:		db	0
isspressed:		db	0

;******************PONTOK ÉS SZINTEK **************************
;Eredeti Nintendo Scoring System BCD 1-4 sor => 40, 100 , 300, 1200
scr1: 			db $40,$00,$00,$00
scr2: 			db $00,$01,$03,$12
scr3: 			db $00,$00,$00,$00
score: 			db $00,$00,$00,$00
hiscore:		db $00,$00,$00,$00	
scorethis:		db $00,$00,$00,$00
linecount: 		db $00
level:			db 1			;aktuális level
linecounter:	db 0			;számolja, hogy hány sor tűnt el, 10-nél jöhet a köv. szint

;****************** IDŐZÍTÉS *****************
timerLow:		db $80
timerHi:		db $4
tmodeLow: 			;'level' 0 - frefall, 1 - level1, 2 level2, ...  - level19
db 80,160,160,160,160,160,160,080,160,080,160,080,160,080,160,080,080,080,080,080
tmodeHi: 
db 1,015,014,012,010,009,008,008,007,007,006,006,005,005,004,004,003,003,002,001
fastfall:		db 0;0 - no, 1 - fast fall	

;******************* RANDOM NUMBERS
rindex:			db 74			;ez lehet majd a seed (pl. tovább gombnál r értéke ide be)
;random.org-al generálva
rnumbers:		db 1,3,1,5,2,4,5,3,3,0,3,6,1,0,3,6,5,1,1,4,4,6,1,2,2,5,3,3,3,1,3,0  
				db 0,6,4,4,3,1,3,1,2,4,4,6,2,1,6,1,6,2,5,3,3,3,1,2,3,6,0,0,5,6,6,1
				db 2,0,0,5,5,5,3,3,1,0,4,3,2,6,3,4,0,5,0,4,2,2,3,4,0,6,1,3,4,3,4,6
				db 2,1,1,0,4,2,0,0,2,2,5,6,0,4,4,0,5,4,5,2,5,3,4,1,0,4,0,0,1,4,5,2
				db 2,4,2,4,6,0,5,6,0,0,3,0,5,4,3,2,4,6,3,3,4,3,3,3,1,5,6,1,4,6,1,6
				db 5,4,5,3,4,3,0,6,4,0,0,6,2,1,2,0,0,2,3,5,2,4,6,0,2,4,0,2,1,0,2,2
				db 5,4,4,6,3,1,2,2,5,6,0,6,4,4,6,3,2,3,4,4,4,5,5,1,3,1,6,1,1,1,4,5
				db 3,4,5,1,4,4,2,4,0,4,1,6,1,1,5,4,4,1,6,5,3,0,3,6,6,2,5,0,2,3,3,1


blStart:
	db 00,08,16,24,28,32,36
blEnd:
	db 06,14,22,26,30,34,36


frLoHi:
	dw fr00, fr01, fr02, fr03
	dw fr10, fr11, fr12, fr13
	dw fr20, fr21, fr22, fr23
	dw fr30, fr31					
	dw fr40, fr41					
	dw fr50, fr51					
	dw fr60								


; block0 with 4 frames 00, 01, 02, 03
;   *
; *** 
;  	
fr00:
	db $20,$20,$20,$0c
	db $20,$0c,$0c,$0c
	db $20,$20,$20,$20
	db $20,$20,$20,$20
fr01:
	db $20,$0c,$20,$20
	db $20,$0c,$20,$20
	db $20,$0c,$0c,$20
	db $20,$20,$20,$20
fr02:
	db $20,$20,$20,$20
	db $20,$0c,$0c,$0c
	db $20,$0c,$20,$20
	db $20,$20,$20,$20
fr03:
	db $20,$0c,$0c,$20
	db $20,$20,$0c,$20
	db $20,$20,$0c,$20
	db $20,$20,$20,$20

; block1 with 4 frames 10, 11, 12, 13
;  *
; ***


fr10:
	db $20,$20,$0c,$20
	db $20,$0c,$0c,$0c
	db $20,$20,$20,$20
	db $20,$20,$20,$20
fr11:
	db $20,$20,$0c,$20
	db $20,$20,$0c,$0c
	db $20,$20,$0c,$20
	db $20,$20,$20,$20
fr12:
	db $20,$20,$20,$20
	db $20,$0c,$0c,$0c
	db $20,$20,$0c,$20
	db $20,$20,$20,$20
fr13:
	db $20,$20,$0c,$20
	db $20,$0c,$0c,$20
	db $20,$20,$0c,$20
	db $20,$20,$20,$20

; block2 with 4 frames 20, 21, 22, 23
; *
; ***

fr20:
	db $0c,$20,$20,$20
	db $0c,$0c,$0c,$20
	db $20,$20,$20,$20
	db $20,$20,$20,$20
fr21:
	db $20,$0c,$0c,$20
	db $20,$0c,$20,$20
	db $20,$0c,$20,$20
	db $20,$20,$20,$20
fr22:
	db $20,$20,$20,$20
	db $0c,$0c,$0c,$20
	db $20,$20,$0c,$20
	db $20,$20,$20,$20
fr23:
	db $20,$0c,$20,$20
	db $20,$0c,$20,$20
	db $0c,$0c,$20,$20
	db $20,$20,$20,$20

; block3 with 2 frames 30, 31
;  **
; **

fr30:
	db $20,$0c,$0c,$20
	db $0c,$0c,$20,$20
	db $20,$20,$20,$20
	db $20,$20,$20,$20
fr31:
	db $20,$0c,$20,$20
	db $20,$0c,$0c,$20
	db $20,$20,$0c,$20
	db $20,$20,$20,$20

; block4 with 2 frames 40, 41
; **
;  **

fr40:
	db $0c,$0c,$20,$20
	db $20,$0c,$0c,$20
	db $20,$20,$20,$20
	db $20,$20,$20,$20
fr41:
	db $20,$20,$0c,$20
	db $20,$0c,$0c,$20
	db $20,$0c,$20,$20
	db $20,$20,$20,$20

; block5 with 2 frames 50, 51
; 
; ****

fr50:
	db $20,$20,$20,$20
	db $0c,$0c,$0c,$0c
	db $20,$20,$20,$20
	db $20,$20,$20,$20
fr51:
	db $20,$0c,$20,$20
	db $20,$0c,$20,$20
	db $20,$0c,$20,$20
	db $20,$0c,$20,$20
	
; block6 with 1 frames 60
; 
; **
; **
; 
fr60:
	db $20,$20,$20,$20
	db $20,$0c,$0c,$20
	db $20,$0c,$0c,$20
	db $20,$20,$20,$20
	
rcounter:	db 0	;időzítő az R forgatásához a title-nél
rdir:		db 0	;R köv. forgatási iránya
r1:
db 255,255,255,255,255,212
db 255,255,255,255,255,255
db 255,255, 32, 32,255,255
db 255,255,255,255,255, 27
db 255,255,255,255,212, 32
db 255,255, 28,255,255,212
db 255,255, 32, 28,255,255
db 255,255, 32, 32, 28,255 		

r2:
db 32,32,255,255,32,32
db 32,32,255,255,32,32
db 32,32,255,255,32,32
db 32,32,255,255,32,32
db 32,32,255,255,32,32
db 32,32,255,255,32,32
db 32,32,255,255,32,32
db 32,32,255,255,32,32

r3:
db  29,255,255,255,255,255
db 255,255,255,255,255,255
db 255,255, 32, 32,255,255
db  28,255,255,255,255,255
db  32, 29,255,255,255,255
db  29,255,255, 27,255,255
db 255,255, 27, 32,255,255
db 255, 27, 32, 32,255,255


gotext:
db 32,0,0,0,0,0,0,0,0,0,0,0,0,0
db 32,0,0,0,142,146,146,143,0,0,0,0,0,0
db 32,142,146,146,145,28,32,144,146,146,146,146,143,32
db 32,147,213,0,213,22,31,29,31,27,22,31,147,32
db 32,147,234,234,0,22,32,234,32,30,22,32,147,32
db 32,147,32,213,32,21,18,28,18,213,21,18,147,0
db 32,144,146,146,146,146,146,146,146,146,146,146,145,0
db 32,32,32,32,32,32,32,32,32,32,32,32,32,32


titlescreen:
; character codes (1000 bytes)
db  32, 32, 22, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 31, 23, 32, 32, 32
db  32, 32,213, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,  0,  0,  0,  0,  0,234, 32, 32, 32
db  32, 32,213,234,255,255,255,255,213,255,255,255,255,255,234,255,255,255,255,213,255,255,255,255,255,212,234,255,213, 24,255,255,255,255, 22, 32,234,146,143, 32
db  32, 32,213,234,255,255,255,255,213,255,255,255,255,255,234,255,255,255,255,213,255,255,255,255,255,255,234,255,213,255,255,255,255, 22,  0, 32,234, 32,147, 32
db  32, 32,213, 32, 32,255,255, 32, 32,255,255,  0, 32, 32, 32, 32,255,255, 32, 32,255,255, 32, 32,255,255,234,255,213, 28,255,255, 30,  0,  0, 32,234, 32,147, 32
db  32, 32,213, 32, 32,255,255, 32, 32,255,255,255,255, 22, 32, 32,255,255, 32, 32,255,255,255,255,255, 27,234,255,213, 32, 28,255,255, 30,  0, 32,234, 32,147, 32
db  32, 32,213, 32, 32,255,255, 32, 32,255,255,255, 22,  0, 32, 32,255,255, 32, 32,255,255,255,255,212, 32,234,255,213, 32, 32, 28,255,255, 30, 32,234, 32,147, 32
db  32, 32,213, 32, 32,255,255, 32, 32,255,255,  0,  0,  0, 32, 32,255,255, 32, 32,255,255, 28,255,255,212,234,255,213, 32, 32,  0, 28,255,255, 32,234, 32,147, 32
db  32, 32,213, 32, 32,255,255, 32, 32,255,255,255,255,255, 32, 32,255,255, 32, 32,255,255, 32, 28,255,255,234,255,213,255,255,255,255,255,255, 32,234, 32,147, 32
db  32, 32,213, 32, 32,255,255, 32, 32, 28,255,255,255,255, 32, 32,255,255, 32, 32,255,255, 32, 32, 28,255,234,255,213,255,255,255,255,255, 27, 32,234, 32,147, 32
db  32, 32,213, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,  0, 32, 32, 32, 32,234, 32,147, 32
db  32, 32, 21, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 30,  0, 32, 32, 32, 32, 32, 32, 32, 32, 32,  0, 29, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 24, 32,147, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32, 32, 32, 32, 32, 32, 32, 32, 32, 46, 32,234, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,147, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,234, 32,142,146,146,146,146,146,146,146,146,146,146,145, 32
db  32, 32, 32, 32, 32, 32, 32, 42, 32, 32, 32, 32, 32,213, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db   0, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 46, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32, 32, 32, 32,148, 32, 32, 32, 32, 32, 32,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 43, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32, 32, 32, 32,152,  0,  0, 32, 32, 32, 32,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 46, 32, 32, 32,213, 32, 32,160, 40,255, 41, 32,148, 32, 32, 32,234, 32,147, 32, 32, 32, 42, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32, 43,183,234, 12,213, 40,152, 41, 19, 32,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213, 32,151,183, 12, 12, 12, 40,  3, 41,234, 32,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,213,254,255,255,255,255,255,254,255,253,255, 21,234, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 21, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 24, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,147, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32,144,146,146,146,146,146,146,146,146,146,146,146,145, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
db  32, 32, 32, 32, 32, 32, 32, 32,32, 32, 32, 32, 32, 32, 32, 32,32, 32, 32, 32, 32, 32, 32, 32,32, 32, 32, 32, 32, 32, 32, 32,32, 32, 32, 32, 32, 32, 32, 32,32,32
db 32,32,32,32,32,32,75,111,108,109,97,32,75,111,114,110,123,108,32,40,75,111,45,75,111,41,32,50,48,50,52,32,32,32,32,32,32,32,32,32


gamescreen:
db 142,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,190,146,190,146,146,146,146,146,146,190,146,190,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,143,147,0,0,0,0,32,32,32,32,0,32,32,0,0,0,0,0,0,0,32,32,32,32,32,32,32,32,32,32,32,147,32,147,49,48,49,48,49,48,147,32,147,32,0,32,32,32,0,0,0,0,0,0,0,32,32,32,32,32,32,32,32,32,147,147,0,142,146,146,143,32,32,32,32,32,32,32,22,31,31,31,31,31,31,31,31,23,32,32,0,32,32,32,32,147,0,144,146,146,146,146,146,146,145,0,147,0,0,0,32,32,32,22,31,31,31,31,31,31,31,31,31,23,32,32,32,32,147,147,0,147,98,121,147,32,32,32,32,32,32,32,213,80,79,78,84,83,90,64,77,234,32,32,0,32,32,32,32,147,32,32,32,32,32,32,32,32,32,32,147,32,32,32,0,32,32,213,75,92,86,69,84,75,69,90,188,234,32,32,32,32,147,147,0,147,32,32,144,146,146,143,32,0,0,0,213,0,0,0,0,0,0,0,0,234,0,0,32,32,32,32,32,147,32,32,32,32,32,32,32,32,32,32,147,32,32,32,0,0,0,213,0,0,0,0,0,0,0,0,32,234,32,32,32,32,147,147,0,147,75,111,45,75,111,147,0,32,32,32,213,48,48,48,48,48,48,48,48,234,32,32,32,32,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,0,32,32,213,32,32,32,32,32,32,32,32,32,234,32,32,32,32,147,147,32,144,146,146,146,146,146,145,32,32,32,32,255,182,182,182,182,182,182,182,182,255,32,32,0,32,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,0,32,0,0,0,213,32,32,32,32,32,32,32,32,32,234,0,0,0,0,147,147,32,32,32,32,32,0,32,32,32,32,32,32,213,82,69,75,79,82,68,32,32,234,32,32,0,32,32,32,0,255,32,32,32,32,32,32,32,32,32,32,255,0,0,0,0,32,32,213,32,32,32,32,32,32,32,32,32,234,32,32,32,32,147,147,32,32,32,32,0,0,32,32,32,32,32,32,213,32,32,32,32,32,32,32,32,234,32,32,0,0,0,0,0,255,32,32,32,32,32,32,32,32,32,32,255,0,0,0,0,32,32,213,32,32,32,32,32,32,32,32,32,234,32,32,32,32,147,147,32,32,32,32,0,0,32,32,32,32,32,32,213,48,48,48,48,48,48,48,48,234,32,32,32,0,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,0,0,0,21,18,18,18,18,18,18,18,18,18,24,32,32,32,32,147,147,0,0,0,0,32,0,0,32,32,32,32,32,255,182,182,182,182,182,182,182,182,255,32,32,32,0,0,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,32,0,32,32,32,32,32,32,32,32,32,0,32,32,32,32,32,32,147,147,32,32,0,0,0,0,0,0,0,0,0,0,213,83,90,73,78,84,32,32,32,234,32,32,32,0,0,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,32,32,32,0,32,32,32,32,32,32,32,32,32,0,0,32,32,32,147,147,32,32,0,0,32,32,32,32,32,32,32,32,213,32,32,32,32,32,32,32,32,234,32,32,32,0,0,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,32,32,142,146,146,143,32,32,32,32,32,32,32,0,0,32,32,32,147,147,32,32,32,0,32,32,32,32,32,32,32,32,213,48,48,32,32,32,32,32,32,234,32,32,32,0,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,32,32,147,15,15,147,32,32,32,32,32,32,32,0,32,32,32,32,147,147,32,32,32,0,32,32,32,32,32,32,32,32,21,18,18,18,18,18,18,18,18,24,32,32,32,0,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,32,32,147,15,15,144,146,146,143,32,32,32,32,0,32,32,32,32,147,147,32,32,32,0,32,32,32,32,32,32,32,32,32,32,32,32,32,32,0,32,32,32,32,32,0,0,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,32,32,147,15,15,15,15,15,147,32,32,32,32,0,32,32,32,32,147,147,32,32,32,32,0,32,0,32,32,32,32,32,32,32,32,32,32,32,0,0,32,32,32,32,32,0,0,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,142,146,145,15,15,15,15,15,147,32,32,32,32,0,32,32,32,32,147,147,32,32,32,32,0,32,0,32,32,32,32,142,146,190,146,146,146,146,146,146,190,146,143,32,32,0,0,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,32,32,30,15,15,147,32,32,32,32,0,0,32,32,0,147,147,32,32,32,32,0,32,0,32,32,32,32,147,65,147,102,111,114,103,97,116,147,83,147,32,32,0,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,0,0,0,147,255,255,32,255,32,15,15,147,32,32,32,32,32,0,32,32,0,147,147,32,32,32,32,0,32,0,32,32,32,32,144,146,191,146,190,146,190,146,146,191,146,145,32,32,0,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,28,32,32,15,15,144,146,146,146,146,146,146,146,146,143,147,147,32,32,32,32,32,0,142,146,146,146,146,146,146,146,146,145,9,144,146,146,146,146,146,146,146,146,143,0,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,32,32,32,15,15,32,80,108,101,97,115,117,114,101,147,147,147,32,32,32,32,32,0,147,0,98,97,108,114,97,32,10,32,32,0,11,32,106,111,98,98,114,97,147,0,0,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,32,32,15,15,15,32,66,121,116,101,115,46,142,146,145,147,147,32,32,32,32,32,32,144,146,146,146,146,146,146,146,146,143,8,142,146,146,146,146,146,146,146,146,145,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,32,32,15,15,15,32,71,97,109,101,115,142,145,32,32,147,147,32,32,32,32,32,32,32,32,32,0,32,32,32,32,142,145,32,144,143,32,32,32,32,0,32,32,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,255,255,142,146,146,146,146,146,146,146,146,145,32,32,32,147,147,32,32,32,32,32,32,32,32,32,0,32,32,32,32,147,101,106,116,147,32,32,32,32,0,32,32,32,32,32,255,32,32,32,32,32,32,32,32,32,32,255,32,32,32,147,255,255,255,255,147,32,32,32,32,32,0,0,32,32,32,32,32,147,147,32,32,32,32,32,32,32,32,32,0,32,32,32,32,158,146,146,146,159,32,32,32,32,0,32,32,32,32,32,255,255,255,255,255,255,255,255,255,255,255,255,32,32,32,144,190,146,146,146,191,146,146,146,146,146,146,146,146,146,143,32,32,147,147,32,32,32,32,32,32,32,32,32,0,32,0,32,32,147,100,111,98,147,32,32,32,32,0,0,0,0,32,32,32,0,0,0,32,32,0,32,32,0,32,32,32,32,32,32,147,22,26,234,31,27,213,234,234,32,234,29,31,30,147,32,0,147,147,32,0,0,0,0,0,0,0,0,0,0,32,32,142,145,32,32,32,144,143,32,32,0,0,32,32,0,32,32,32,32,0,0,32,32,0,32,32,0,32,32,32,0,0,0,147,22,27,234,27,32,25,26,234,32,234,234,32,213,147,0,0,147,147,32,32,0,0,32,0,32,32,32,0,0,0,0,147,83,80,65,67,69,147,0,0,0,0,32,32,32,32,32,32,32,0,0,0,0,0,0,32,0,0,0,0,0,0,32,147,213,32,234,18,30,213,234,234,29,234,28,18,27,147,32,0,147,147,32,32,0,0,32,0,32,32,32,32,32,32,32,144,146,146,146,146,146,145,32,32,32,32,32,32,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32,32,0,32,144,146,146,146,146,146,146,146,146,146,146,146,146,146,145,32,32,147,147,32,32,0,32,32,32,32,32,32,32,32,32,0,32,32,32,32,32,32,32,32,32,32,32,32,0,32,32,32,32,32,0,32,0,0,0,0,32,0,32,32,32,32,0,32,32,0,32,32,32,0,32,32,32,32,32,32,32,32,32,32,32,147,144,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,146,145

vege:	db $19,$74