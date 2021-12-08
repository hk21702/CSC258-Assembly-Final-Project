#####################################################################
#
# CSC258H5S Fall 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: 
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 5
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. Randomized hazard interval and size
# 2. Death Animation
# 3. Game Over/Reset Screen
# 4. Life Counter
# 5. Have objects in different rows move at different speeds.
# 6. (hard) Add sound effects for movement, collisions, game end and reaching the goal area.
# 
# Any additional information that the TA needs to know:
# - MARS likes to crash if you hold down a button. This seems to be an issue with MARS
# - If one tries enters the goal region but the spot is already occupied or partially occupied, frog will reset without life penalty but no gain in score. This is intentional.
####################################################################
	.data
## Scoring ##
lives: .word 3
score: .word 0
## Colors ##
frogColor: .word 0x4fa64f
logColor: .word 0x742913
waterColor: .word 0x26b7ff
grassColor: .word 0xabd5ab
roadColor: .word 0x999999
carColor: .word 0xdbbfd5
safeColor: .word 0xFFBF00
text1Color: .word 0xD787DA
text2Color: .word 0xb66a6a
heartColor: .word 0xa13a3c
## Dynamic Positions (x, y) 32 x 32 display ##
## Positiosn represent top right of sprite
frogX: .word 14
frogY: .word 28
frogXI: .word 14
frogYI: .word 28
setOverlay: .space 4096 # 32 * 32 * 4
entityOverlay: .space 4096
victoryOverlay: .space 4096
infoOverlay: .space 4096
## Fixed Positions
cars1Region: .word 20
cars2Region: .word 24
logs1Region: .word 8
logs2Region: .word 12
regionHeight: .word 4
frogWidth: .word 4
frogHeight: .word 4
endRegion: .word 4
## 
cars1Counter: .word 2
cars2Counter: .word 4
logs1Counter: .word 2
logs2Counter: .word 4
cars1State: .space 4
cars2State: .space 4
logs1State: .space 4
logs2State: .space 4
frameDelayC1: .word 25
frameDelayC2: .word 15
frameDelayL1: .word 20
frameDelayL2: .word 10
frameCounterC1: .word 0
frameCounterC2: .word 0
frameCounterL1: .word 0
frameCounterL2: .word 0
shiftIntervalMax: .word 5
shiftIntervalMin: .word 2
## Sound ##
movementI: .word 9 #8-15
movementS: .word 72
deathI: .word 32
deathS: .word 55
scoreI: .word 9
scoreS: .word 100
## Other ##
tmp: .word 0
soundVolume: .word 60 #0-127
displayAddress: .word 0x10008000 #Just use $gp
displayWidth: .word 32 # Width of display
displayHeight: .word 32 # Height of display
msFrameDelay: .word 15 # milliSecs between frames (16.67 for 60 FPS assuming instant draw speed)
## Notes ##
# $a0 is reserved for color
####################################################################
	.text   
main:
	jal initRegions
	jal initCars1
	jal initCars2
	jal initLogs1
	jal initLogs2
	jal initShifters

	jal updateHeartDisplay

	gameLoop:
	# Tick framecounter
	la $t0, frameCounterL1
	lw $t4, 0($t0)
	addi $t4, $t4, 1
	sw $t4, 0($t0)

	la $t0, frameCounterL2
	lw $t4, 0($t0)
	addi $t4, $t4, 1
	sw $t4, 0($t0)

	la $t0, frameCounterC1
	lw $t4, 0($t0)
	addi $t4, $t4, 1
	sw $t4, 0($t0)

	la $t0, frameCounterC2
	lw $t4, 0($t0)
	addi $t4, $t4, 1
	sw $t4, 0($t0)

	# Check if hazard change appropriate
	lw $t0, frameCounterL1
	lw $t1, frameDelayL1
	blt $t0, $t1, shiftL2
	### Update Hazards ###
	# Reset frame counter
	la $t0, frameCounterL1
	li $t4, 0
	sw $t4, 0($t0)
	jal shiftLogs1

	shiftL2:
	# Check if hazard change appropriate
	lw $t0, frameCounterL2
	lw $t1, frameDelayL2
	blt $t0, $t1, shiftC1
	### Update Hazards ###
	# Reset frame counter
	la $t0, frameCounterL2
	li $t4, 0
	sw $t4, 0($t0)
	jal shiftLogs2
	
	shiftC1:
	# Check if hazard change appropriate
	lw $t0, frameCounterC1
	lw $t1, frameDelayC1
	blt $t0, $t1, shiftC2
	### Update Hazards ###
	# Reset frame counter
	la $t0, frameCounterC1
	li $t4, 0
	sw $t4, 0($t0)
	jal shiftCars1
	
	shiftC2:
	# Check if hazard change appropriate
	lw $t0, frameCounterC2
	lw $t1, frameDelayC2
	blt $t0, $t1, gameLoopEnd
	### Update Hazards ###
	# Reset frame counter
	la $t0, frameCounterC2
	li $t4, 0
	sw $t4, 0($t0)
	jal shiftCars2

	gameLoopEnd:
	jal clearFrog
	lw $t8, 0xffff0000
	beq $t8, 1, keyboardInput
	jal drawFrog
	jal draw
	jal collisionCheck
	jal checkVictory

	# Delay till next frame
	li $v0, 32 
	lw $a0, msFrameDelay
	syscall 
	j gameLoop
	j Exit

keyboardInput:
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	lw $t2, 0xffff0004
	
	beq $t2, 0x77, respondW
	beq $t2, 0x61, respondA
	beq $t2, 0x73, respondS
	beq $t2, 0x64, respondD

	respondW:

		la $t0, frogY
		lw $t4, 0($t0)
		li $t1, 3 
		ble $t4, $t1, wExit

		lw $a0 movementS
		li $a1, 120
		lw $a2, movementI
		li $a3, 100 
		li $v0,31
		syscall

		addi $t4, $t4, -4
		sw $t4, 0($t0)
		wExit:
		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra	

	respondA:

		la $t0, frogX
		lw $t4, 0($t0)
		li $t1, 0 
		ble $t4, $t1, aExit

		lw $a0 movementS
		li $a1, 120
		lw $a2, movementI
		li $a3, 100 
		li $v0,31
		syscall

		addi $t4, $t4, -1
		sw $t4, 0($t0)
		aExit:
		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra

	respondS:

		la $t0, frogY
		lw $t4, 0($t0)
		lw $t1, displayHeight
		lw $t2, frogHeight
		sll $t2, $t2, 1
		subi $t2, $t2, 1
		sub $t1, $t1, $t2
		bge $t4, $t1, sExit

		lw $a0 movementS
		li $a1, 120
		lw $a2, movementI
		li $a3, 100 
		li $v0,31
		syscall

		addi $t4, $t4, 4
		sw $t4, 0($t0)
		sExit:
		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra

	respondD:

		la $t0, frogX
		lw $t4, 0($t0)
		lw $t1, displayWidth
		lw $t2, frogWidth
		sub $t1, $t1, $t2
		bge $t4, $t1, dExit

		lw $a0 movementS
		li $a1, 120
		lw $a2, movementI
		li $v0,31
		syscall

		addi $t4, $t4, 1
		sw $t4, 0($t0)
		dExit:
		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra


	# Load $ra from stack
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

	

# void setPixel (
	# set the pixel value at the position address to color
	# 
	# $a0: Color
	# $a3: Position address
setPixel:
	sw $a0, ($a3) # Set address to color
	jr $ra	# return $v0
	
# .word coordianteToAddress
	# Convert coordiantes to bitmap display address
	#
	# $a1: xPos
	# $a2: yPos
	#
	# returns $v0: address of coordinates for the bitmap display
coordinateToAddress:
	# Shift to display pos
	sll $v0, $a2, 7 # Shift y height
	sll $a1, $a1, 2 # x * 4 (shift 2) shift x width
	add $v0, $v0, $a1 # Add x and y
	add $v0, $gp, $v0 # set $v0 to pixel address for bitmap display 
	
	jr $ra	# return $v0

# 
#
drawFrog:
# Save $ra to stack
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	
	lw $a0, frogColor # Load color

	lw $t1, frogX # Load frog top left pos
	lw $t2, frogY
	
	# Column 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos
	
	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, 2
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	# Column 2
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	# Column 3
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	# Column 4
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -2
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

# Load $ra from stack
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

clearFrog:
# Save $ra to stack
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	
	la $a0, ($0) # Load color

	lw $t1, frogX # Load frog top left pos
	lw $t2, frogY
	
	# Column 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos
	
	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, 2
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	# Column 2
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	# Column 3
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	# Column 4
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -2
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtEntityPos

# Load $ra from stack
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra


initRegions:
	# Save $ra to stack
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
############## Draw Start Region
	lw $a0, grassColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 28 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
############## Draw Road
	lw $a0, roadColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 20 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 8 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
############## Draw Safe Region
	lw $a0, safeColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 16 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
############## Draw River Region
	lw $a0, waterColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 8 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 8 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
############## Draw Goal Region
	lw $a0, grassColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 0 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 8 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
# Load $ra from stack
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

# void draw
	# Draw
	#
	# returns none
draw:
	lw $t8, displayWidth # Load displayWidth
	lw $t7, displayHeight # Load displayHeight
 	
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
 		
	li $t1, 0         # Initialize xPos counter
startDrawLoop1:  
	beq $t1, $t8, endDrawLoop1
######################## Inner loop  
	li $t2, 0        # Initialize yPos counter  
startDrawLoop2:  
	beq $t2, $t7, endDrawLoop2  
	
	move $a1, $t1
	move $a2, $t2

	jal getAtOverPos
	move $a0, $v0
	
	move $a1, $t1
	move $a2, $t2
	jal getAtEntityPos
	beq $v0, $0, drawSkip1
	move $a0, $v0 # Override color

	drawSkip1:
	move $a1, $t1
	move $a2, $t2
	jal getAtVictoryPos
	beq $v0, $0, drawSkip2
	move $a0, $v0 # Override color

	drawSkip2:
	move $a1, $t1
	move $a2, $t2
	jal getAtInfoPos
	beq $v0, $0, drawSkip3
	move $a0, $v0 # Override color

	drawSkip3:
	move $a1, $t1
	move $a2, $t2
	jal coordinateToAddress # convert pos to address ($v0 is now address)
	move $a3, $v0
	jal setPixel
  	incRectY:
	addi $t2, $t2, 1    # Increment yPos counter  
	b startDrawLoop2  
endDrawLoop2:  
######################## Inner loop  
	addi $t1, $t1, 1    # Increment xPos counter  
	b startDrawLoop1
endDrawLoop1:
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	
	jr $ra # Exit function
####################################################################

initCars1:
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	lw $a0, carColor

	li $a1, 0 # xPos
	lw $a2, cars1Region # yPos
	li $a3, 8
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect

	li $a1, 16 # xPos
	lw $a2, cars1Region # yPos
	li $a3, 8
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
	
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra

initCars2:
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	lw $a0, carColor

	li $a1, 0 # xPos
	lw $a2, cars2Region # yPos
	li $a3, 4
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect

	li $a1, 12 # xPos
	lw $a2, cars2Region # yPos
	li $a3, 8
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect

	li $a1, 28 # xPos
	lw $a2, cars2Region # yPos
	li $a3, 4
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
	
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra

initLogs1:
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	lw $a0, logColor

	li $a1, 0 # xPos
	lw $a2, logs1Region # yPos
	li $a3, 8
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect

	li $a1, 16 # xPos
	lw $a2, logs1Region # yPos
	li $a3, 8
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
	
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra

initLogs2:
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	lw $a0, logColor

	li $a1, 0 # xPos
	lw $a2, logs2Region # yPos
	li $a3, 4
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect

	li $a1, 12 # xPos
	lw $a2, logs2Region # yPos
	li $a3, 8
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect

	li $a1, 28 # xPos
	lw $a2, logs2Region # yPos
	li $a3, 4
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawSetRect
	
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra

# void drawSetRect
	# Draw rectangle
	#
	# $a0: color
	# $a1: xPos (Top left corner)
	# $a2: yPos (Top left corner)
	# $a3: width
	# $16($sp): height
	# returns none
drawSetRect:
	lw $t5, 16($sp) # Load height from stack
	lw $t8, displayWidth # Load displayWidth
	lw $t7, displayHeight # Load displayHeight
 	
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
 	
	move $t0, $a0 # Save base color
	move $t1, $a1 # Save fixed initial xPos
	move $t2, $a2 # Save fixed initial yPos
	
	move $t3, $t1        # Initialize xPos counter
	move $t4, $t1        # Initialize rightmost position  
	add $t4, $t4, $a3
startSetRectLoop1:  
	beq $t3, $t4, endSetRectLoop1
	bge $t3, $t8, endSetRectLoop1 # Ensure xPos stays on screen
	blt $t3, 0, endSetRectLoop2 # Don't attempt draw if x < 0
######################## Inner loop  
	move $t1, $t2        # Initialize yPos counter  
	move $t6, $t2        # Initialize bottommost position  
	add $t6, $t6, $t5
startSetRectLoop2:  
	beq $t1, $t6, endSetRectLoop2  
	bge $t1, $t7, endSetRectLoop2 # Ensure yPos stays on screen
	blt $t1, 0, incOvRectY # Don't attempt draw if y < 0
	
	move $a0, $t0
	move $a1, $t3
	move $a2, $t1
	jal setAtOverPos

  	incOvRectY:
	addi $t1, $t1, 1    # Increment yPos counter  
	b startSetRectLoop2  
endSetRectLoop2:  
######################## Inner loop  
	addi $t3, $t3, 1    # Increment xPos counter  
	b startSetRectLoop1
endSetRectLoop1:
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	
	jr $ra # Exit function

#
# $a1 xPos
# $a2 yPos
getAtOverPos:
	la $v0, setOverlay
	sll $a1, $a1, 2
	sll $a2, $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	lw $v0, 0($v0)
	jr $ra # Exit function

# $a0 word to set at pos
# $a1 xPos
# $a2 yPos
setAtOverPos:
	la $v0, setOverlay
	sll $a1, $a1, 2
	sll $a2 $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	sw $a0, 0($v0)
	jr $ra

#
# $a1 xPos
# $a2 yPos
getAtEntityPos:
	la $v0, entityOverlay
	sll $a1, $a1, 2
	sll $a2, $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	lw $v0, 0($v0)
	jr $ra # Exit function

# $a0 word to set at pos
# $a1 xPos
# $a2 yPos
setAtEntityPos:
	la $v0, entityOverlay
	sll $a1, $a1, 2
	sll $a2 $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	sw $a0, 0($v0)
	jr $ra

# $a1 xPos
# $a2 yPos
getAtVictoryPos:
	la $v0, victoryOverlay
	sll $a1, $a1, 2
	sll $a2, $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	lw $v0, 0($v0)
	jr $ra # Exit function

# $a0 word to set at pos
# $a1 xPos
# $a2 yPos
setAtVictoryPos:
	la $v0, victoryOverlay
	sll $a1, $a1, 2
	sll $a2 $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	sw $a0, 0($v0)
	jr $ra

#
# $a1 xPos
# $a2 yPos
getAtInfoPos:
	la $v0, infoOverlay
	sll $a1, $a1, 2
	sll $a2, $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	lw $v0, 0($v0)
	jr $ra # Exit function

# $a0 word to set at pos
# $a1 xPos
# $a2 yPos
setAtInfoPos:
	la $v0, infoOverlay
	sll $a1, $a1, 2
	sll $a2 $a2, 7
	add $a1, $a1, $a2
	add $v0, $a1, $v0
	sw $a0, 0($v0)
	jr $ra

clearEntityOverlay:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	
	la $a0, ($0)
	li $a1, 0
	li $a2, 0
	lw $a3, displayWidth
	lw $t1, displayHeight
	sw, $t0, 16($sp)
	jal drawEntityRect

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function


# void drawEntityRect
	# Draw rectangle
	#
	# $a0: color
	# $a1: xPos (Top left corner)
	# $a2: yPos (Top left corner)
	# $a3: width
	# $16($sp): height
	# returns none
drawEntityRect:
	lw $t5, 16($sp) # Load height from stack
	lw $t8, displayWidth # Load displayWidth
	lw $t7, displayHeight # Load displayHeight
 	
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
 	
	move $t0, $a0 # Save base color
	move $t1, $a1 # Save fixed initial xPos
	move $t2, $a2 # Save fixed initial yPos
	
	move $t3, $t1        # Initialize xPos counter
	move $t4, $t1        # Initialize rightmost position  
	add $t4, $t4, $a3
	startEntityRectLoop1:  
		beq $t3, $t4, endEntityRectLoop1
		bge $t3, $t8, endEntityRectLoop1 # Ensure xPos stays on screen
		blt $t3, 0, endEntityRectLoop2 # Don't attempt draw if x < 0
	######################## Inner loop  
		move $t1, $t2        # Initialize yPos counter  
		move $t6, $t2        # Initialize bottommost position  
		add $t6, $t6, $t5
	startEntityRectLoop2:  
		beq $t1, $t6, endEntityRectLoop2  
		bge $t1, $t7, endEntityRectLoop2 # Ensure yPos stays on screen
		blt $t1, 0, incSetRectY # Don't attempt draw if y < 0
		
		move $a0, $t0
		move $a1, $t3
		move $a2, $t1
		jal setAtEntityPos

		incSetRectY:
		addi $t1, $t1, 1    # Increment yPos counter  
		b startEntityRectLoop2  
	endEntityRectLoop2:  
	######################## Inner loop  
		addi $t3, $t3, 1    # Increment xPos counter  
		b startEntityRectLoop1
	endEntityRectLoop1:
		lw $ra,  0($sp) # Load $ra from stack
		addi $sp, $sp, 4
		jr $ra # Exit function

initShifters:
	lw $t9, waterColor
	lw $t8, logColor
	lw $t7, roadColor
	lw $t6, carColor

	### Set region states ###
	# logs1
	la $t0, logs1State
	sw $t9, 0($t0)

	# logs2
	la $t0, logs2State
	sw $t8, 0($t0)

	# cars1
	la $t0, cars1State
	sw $t7, 0($t0)

		# cars1
	la $t0, cars2State
	sw $t6, 0($t0)

jr $ra # Exit function

shiftLogs1:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	la $t0, logs1Counter # Load counter
	lw $t1 0($t0)
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	# If no more, reset
	bgt $t1, 0, shiftLog1

	lw $a1, shiftIntervalMax
	lw $a2, shiftIntervalMin
	jal getRandomNum
	sll $v0, $v0, 1 # Multiply by 2
	sw $v0, 0($t0) # Set new interval

	#State flip
	la $a0, logs1State # Load state address
	jal flipLogState

	shiftLog1:
	# Loop init
	li $t0, 0 # Load xPos counter
	
	# Loop start
	shiftLog1Start:
	lw $t1, displayWidth
	addi $t1, $t1, -1
	
	beq $t0, $t1, shiftLog1End 
	addi $a1, $t0, 1 # Sample xPos
	lw $a2, logs1Region # Sample yPos
	jal getAtOverPos
	
	move $a0 ,$v0 # Set color
	move $a1, $t0 # Set xPos
	lw $a2, logs1Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height

	addi $sp, $sp, -4 
	
	la $t1, tmp 
	sw $t0, 0($t1) # Push $t0 to tmp register
	
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect
	lw $t0,  tmp # Load $t0 from register
	addi $sp, $sp, 4

	addi $t0, $t0, 1 # Increment counter
	j shiftLog1Start
	shiftLog1End:
	lw $a0, logs1State # Set color
	li $a1, 31 # Set xPos
	lw $a2, logs1Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect

	# Shift frog if frog on region
	lw $t0, frogY # Load frog Y
	lw $t1, logs1Region # Load region Y
	beq $t0, $t1, log1FrogShift
	j log1EndEnd
	log1FrogShift:
		jal shiftFrogLeft
	log1EndEnd:
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

shiftFrogLeft:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
		la $t0, frogX
		lw $t4, 0($t0)

		li $t1, 0
		lw $t2, displayWidth
		lw $t3, frogWidth
		sub $t2, $t2, $t3
		beq $t4, $t1, shiftFLeftDeath
		beq $t4, $t2, shiftFLeftDeath

	jal clearFrog

		la $t0, frogX
		lw $t4, 0($t0)
		addi $t4, $t4, -1
		sw $t4, 0($t0)
		j shiftFrogLeftEnd
	shiftFLeftDeath:
	jal death
	shiftFrogLeftEnd:
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

shiftFrogRight:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	 	la $t0, frogX
		lw $t4, 0($t0)

		li $t1, 0
		lw $t2, displayWidth
		lw $t3, frogWidth
		sub $t2, $t2, $t3
		beq $t4, $t1, shiftFRightDeath
		beq $t4, $t2, shiftFRightDeath

	jal clearFrog

		la $t0, frogX
		lw $t4, 0($t0)
		addi $t4, $t4, 1
		sw $t4, 0($t0)
		j shiftFrogRightEnd
	shiftFRightDeath:
	jal death
	shiftFrogRightEnd:
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

shiftLogs2:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	la $t0, logs2Counter # Load counter
	lw $t1 0($t0) # Increment counter down
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	# If no more, reset
	bgt $t1, 0, shiftLog2

	lw $a1, shiftIntervalMax
	lw $a2, shiftIntervalMin
	jal getRandomNum
	sll $v0, $v0, 1 # Multiply by 2
	sw $v0, 0($t0) # Set new interval

	#State flip
	la $a0, logs2State # Load state address
	jal flipLogState

	shiftLog2:
	# Loop init
	lw $t0, displayWidth  # Load xPos counter
	addi $t0 $t0, -1

	# Loop start
	shiftLog2Start:
	li $t1, 0
	
	beq $t0, $t1, shiftLog2End 
	addi $a1, $t0, -1 # Sample xPos
	lw $a2, logs2Region # Sample yPos
	jal getAtOverPos
	
	move $a0 ,$v0 # Set color
	move $a1, $t0 # Set xPos
	lw $a2, logs2Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height

	addi $sp, $sp, -4 

	la $t1, tmp 
	sw $t0, 0($t1) # Push $t0 to tmp register

	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect
	lw $t0,  tmp # Load $t0 from tmp register
	addi $sp, $sp, 4

	addi $t0, $t0, -1 # Increment counter
	j shiftLog2Start
	shiftLog2End:
	lw $a0, logs2State # Set color
	li $a1, 0 # Set xPos
	lw $a2, logs2Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect

	# Shift frog if frog on region
	lw $t0, frogY # Load frog Y
	lw $t1, logs2Region # Load region Y
	beq $t0, $t1, log2FrogShift
	j log2EndEnd
	log2FrogShift:
		jal shiftFrogRight
	log2EndEnd:

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

#
# $a0 -> log region address
flipLogState:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

 	lw $v0, 0($a0) # Load state

	lw $t9 logColor
	lw $t8 waterColor
	
	# Check old state
	beq $t9, $v0, flipLogToWater
	move $v0, $t9 
	j logStateExit
	
	flipLogToWater:
	move $v0, $t8

	logStateExit:
	sw $v0, 0($a0) # Set new state

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

flipCarState:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

 	lw $v0, 0($a0) # Load state

	lw $t9 carColor
	lw $t8 roadColor
	
	# Check old state
	beq $t9, $v0, flipCarToRoad
	move $v0, $t9 
	j carStateExit
	
	flipCarToRoad:
	move $v0, $t8

	carStateExit:
	sw $v0, 0($a0) # Set new state

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

shiftCars1:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	la $t0, cars1Counter # Load counter
	lw $t1 0($t0)
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	# If no more, reset
	bgt $t1, 0, shiftCar1

	lw $a1, shiftIntervalMax
	lw $a2, shiftIntervalMin
	jal getRandomNum
	sll $v0, $v0, 1 # Multiply by 2
	sw $v0, 0($t0) # Set new interval

	#State flip
	la $a0, cars1State # Load state address
	jal flipCarState

	shiftCar1:
	# Loop init
	li $t0, 0 # Load xPos counter
	
	# Loop start
	shiftCar1Start:
	lw $t1, displayWidth
	addi $t1, $t1, -1
	
	beq $t0, $t1, shiftCar1End 
	addi $a1, $t0, 1 # Sample xPos
	lw $a2, cars1Region # Sample yPos
	jal getAtOverPos
	
	move $a0 ,$v0 # Set color
	move $a1, $t0 # Set xPos
	lw $a2, cars1Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height

	addi $sp, $sp, -4 
 	la $t1, tmp 
	sw $t0, 0($t1) # Push $t0 to tmp register
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect
	lw $t0,  tmp # Load $t0 from tmp register
	addi $sp, $sp, 4

	addi $t0, $t0, 1 # Increment counter
	j shiftCar1Start
	shiftCar1End:
	lw $a0, cars1State # Set color
	li $a1, 31 # Set xPos
	lw $a2, cars1Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

shiftCars2:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	la $t0, cars2Counter # Load counter
	lw $t1 0($t0) # Increment counter down
	addi $t1, $t1, -1
	sw $t1, 0($t0)
	# If no more, reset
	bgt $t1, 0, shiftCar2

	lw $a1, shiftIntervalMax
	lw $a2, shiftIntervalMin
	jal getRandomNum
	sll $v0, $v0, 1 # Multiply by 2
	sw $v0, 0($t0) # Set new interval

	#State flip
	la $a0, cars2State # Load state address
	jal flipCarState

	shiftCar2:
	# Loop init
	lw $t0, displayWidth  # Load xPos counter
	addi $t0 $t0, -1

	# Loop start
	shiftCar2Start:
	li $t1, 0
	
	beq $t0, $t1, shiftCar2End 
	addi $a1, $t0, -1 # Sample xPos
	lw $a2, cars2Region # Sample yPos
	jal getAtOverPos
	
	move $a0 ,$v0 # Set color
	move $a1, $t0 # Set xPos
	lw $a2, cars2Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height

	addi $sp, $sp, -4 
 	la $t1, tmp 
	sw $t0, 0($t1) # Push $t0 to tmp register
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect
	lw $t0,  tmp # Load $t0 from stack
	addi $sp, $sp, 4

	addi $t0, $t0, -1 # Increment counter
	j shiftCar2Start
	shiftCar2End:
	lw $a0, cars2State # Set color
	li $a1, 0 # Set xPos
	lw $a2, cars2Region # Set yPos
	li $a3, 1 # Set width
	li, $t2, 4 # Set height
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

# $a1 -> upperbound
# $a2 -> lowerbound
getRandomNum:
	li $v0, 42
	li $a0, 0
	sub $a1, $a1, $a2 # Shift upper bound
	syscall
	add $v0, $a0, $a2 # Apply lower bound
	jr $ra # Exit function

death:
	 	addi $sp, $sp, -4 
 		sw $ra, 0($sp) # Push $ra to stack

		# Remove life
		la $t0, lives
		lw $t4, 0($t0)
		addi $t4, $t4, -1
		sw $t4, 0($t0)

		jal updateHeartDisplay

		lw $t4, lives

		li $t9, 0 # Init counter
		death_animation_loop:
		li $t1, 4 # Init max count
		beq $t9, $t1, death_animation_end
			# Delay
			lw $a0 deathS
			li $a1, 180
			lw $a2, deathI
			li $a3, 127
			li $v0, 33 
			syscall 

			jal clearFrog
			jal draw

			# Delay
			lw $a0, msFrameDelay
			sll $a0, $a0, 4
			li $v0, 32
			syscall 

			jal drawFrog
			jal draw

			addi $t9, $t9, 1
			j death_animation_loop
		death_animation_end:
		# Ignore extra keystrokes
		li $t8, 0
		sw $t0, 0xffff0004
		lw $t2, 0xffff0004
		# Skip reset if no more lives
		beq $t4, 0, gameOverScreen
		jal resetFrogPos
		# Ignore extra keystrokes
		li $t8, 0
		lw $t8, 0xffff0000
		lw $t2, 0xffff0004

		deathEnd:
		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra

resetFrogPos:
		addi $sp, $sp, -4 
 		sw $ra, 0($sp) # Push $ra to stack

		jal clearFrog

		la $t0, frogX # Reset frogX
		lw $t4, frogXI
		sw $t4, 0($t0)

		la $t0, frogY # Reset frogY
		lw $t4, frogYI
		sw $t4, 0($t0)

		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra

checkVictory:
		addi $sp, $sp, -4 
 		sw $ra, 0($sp) # Push $ra to stack

		lw $t0, frogY
		lw $t1, endRegion 
		bgt $t0, $t1, noVictory

		lw $t9, frogColor # Load frog color

		# Check if spot filled
		addi $a2, $t0, 3 # Set y pos
		lw $a1, frogX # Set x pos
		jal getAtVictoryPos
		beq $t9, $v0, skipVictory

		addi $a2, $t0, 3 # Set y pos
		lw $a1, frogX # Set x pos
		addi $a1, $a1, 1
		jal getAtVictoryPos
		beq $t9, $v0, skipVictory

		addi $a2, $t0, 3 # Set y pos
		lw $a1, frogX # Set x pos
		addi $a1, $a1, 2
		jal getAtVictoryPos
		beq $t9, $v0, skipVictory

		addi $a2, $t0, 3 # Set y pos
		lw $a1, frogX # Set x pos
		addi $a1, $a1, 3
		jal getAtVictoryPos
		beq $t9, $v0, skipVictory


		# Draw
	lw $a0, frogColor
	lw $t1, frogX
	lw $t2, frogY

		# Column 1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos


	addi $t2, $t2, 3
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	# Column 2
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	# Column 3
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	# Column 4
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	addi $t2, $t2, -3
	move $a1, $t1
	move $a2, $t2
	jal setAtVictoryPos

	# Delay
	li $a0 70
	li $a1, 200
	lw $a2, movementI
	li $a3, 127
	li $v0, 33 
	syscall

	# Delay
	li $a0 78
	li $a1, 200
	lw $a2, movementI
	li $a3, 127
	li $v0, 33 
	syscall 

	# Delay
	li $a0 78
	li $a1, 200
	lw $a2, movementI
	li $a3, 127
	li $v0, 33 
	syscall 
	
	skipVictory:
	jal resetFrogPos
	noVictory:
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

collisionCheck:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack

	lw $t1, frogX # Load frog top left pos
	lw $t2, frogY
	lw $t9, carColor # Load car color
	lw $t8, waterColor #Load water color

	
	# Column 1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent
	
	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent


	addi $t2, $t2, 2
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	# Column 2
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	# Column 3
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	addi $t2, $t2, 1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	# Column 4
	addi $t1, $t1, 1

	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	addi $t2, $t2, -2
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent

	addi $t2, $t2, -1
	move $a1, $t1
	move $a2, $t2
	jal getAtOverPos
	beq $v0, $t9, deathCollisionEvent
	beq $v0, $t8, deathCollisionEvent
	j collisionCheckEnd # Skip death if no collision

	deathCollisionEvent:
		jal death
	collisionCheckEnd:
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

# void drawInfoyRect
	# Draw rectangle
	#
	# $a0: color
	# $a1: xPos (Top left corner)
	# $a2: yPos (Top left corner)
	# $a3: width
	# $0($sp): height
	# returns none
drawInfoRect:
	lw $t5, 0($sp) # Load height from stack
	addiu $sp, $sp, 4
	lw $t8, displayWidth # Load displayWidth
	lw $t7, displayHeight # Load displayHeight
 	
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
 	
	move $t0, $a0 # Save base color
	move $t1, $a1 # Save fixed initial xPos
	move $t2, $a2 # Save fixed initial yPos
	
	move $t3, $t1        # Initialize xPos counter
	move $t4, $t1        # Initialize rightmost position  
	add $t4, $t4, $a3
	startInfoRectLoop1:  
		beq $t3, $t4, endInfoRectLoop1
		bge $t3, $t8, endInfoRectLoop1 # Ensure xPos stays on screen
		blt $t3, 0, endInfoRectLoop2 # Don't attempt draw if x < 0
	######################## Inner loop  
		move $t1, $t2        # Initialize yPos counter  
		move $t6, $t2        # Initialize bottommost position  
		add $t6, $t6, $t5
	startInfoRectLoop2:  
		beq $t1, $t6, endInfoRectLoop2  
		bge $t1, $t7, endInfoRectLoop2 # Ensure yPos stays on screen
		blt $t1, 0, incInfoRectY # Don't attempt draw if y < 0
		
		move $a0, $t0
		move $a1, $t3
		move $a2, $t1
		jal setAtInfoPos

		incInfoRectY:
		addi $t1, $t1, 1    # Increment yPos counter  
		b startInfoRectLoop2  
	endInfoRectLoop2:  
	######################## Inner loop  
		addi $t3, $t3, 1    # Increment xPos counter  
		b startInfoRectLoop1
	endInfoRectLoop1:
		lw $ra,  0($sp) # Load $ra from stack
		addi $sp, $sp, 4
		jr $ra # Exit function

drawVictoryRect:
	lw $t5, 16($sp) # Load height from stack
	lw $t8, displayWidth # Load displayWidth
	lw $t7, displayHeight # Load displayHeight
 	
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
 	
	move $t0, $a0 # Save base color
	move $t1, $a1 # Save fixed initial xPos
	move $t2, $a2 # Save fixed initial yPos
	
	move $t3, $t1        # Initialize xPos counter
	move $t4, $t1        # Initialize rightmost position  
	add $t4, $t4, $a3
	startVictoryRectLoop1:  
		beq $t3, $t4, endVictoryRectLoop1
		bge $t3, $t8, endVictoryRectLoop1 # Ensure xPos stays on screen
		blt $t3, 0, endVictoryRectLoop2 # Don't attempt draw if x < 0
	######################## Inner loop  
		move $t1, $t2        # Initialize yPos counter  
		move $t6, $t2        # Initialize bottommost position  
		add $t6, $t6, $t5
	startVictoryRectLoop2:  
		beq $t1, $t6, endVictoryRectLoop2  
		bge $t1, $t7, endVictoryRectLoop2 # Ensure yPos stays on screen
		blt $t1, 0, incVictoryRectY # Don't attempt draw if y < 0
		
		move $a0, $t0
		move $a1, $t3
		move $a2, $t1
		jal setAtVictoryPos

		incVictoryRectY:
		addi $t1, $t1, 1    # Increment yPos counter  
		b startVictoryRectLoop2  
	endVictoryRectLoop2:  
	######################## Inner loop  
		addi $t3, $t3, 1    # Increment xPos counter  
		b startVictoryRectLoop1
	endVictoryRectLoop1:
		lw $ra,  0($sp) # Load $ra from stack
		addi $sp, $sp, 4
		jr $ra # Exit function

clearInfoOverlay:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	
	la $a0, ($0)
	li $a1, 0
	li $a2, 0
	lw $a3, displayWidth
	lw $t1, displayHeight
	addi $sp, $sp, -4 
	sw, $t1, 0($sp)
	jal drawInfoRect

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

clearVictoryOverlay:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	
	la $a0, ($0)
	li $a1, 0
	li $a2, 0
	lw $a3, displayWidth
	lw $t1, displayHeight
	sw, $t1, 16($sp)
	jal drawVictoryRect

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

drawA:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2
	
	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 2
	jal setAtInfoPos
	
	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos
	
	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 4
	jal setAtInfoPos
	

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawG:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 4
	jal setAtInfoPos

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawM:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 3
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 4
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 4
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 4
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 4
	addi $a2, $a2, 4
	jal setAtInfoPos

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawE:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	li $a3, 1
	li $t5, 5
	addi $sp, $sp, -4 
	sw, $t5, 0($sp)
	jal drawInfoRect

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawO:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos
	
	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	li $a3, 1
	li $t5, 5
	addi $sp, $sp, -4 
	sw, $t5, 0($sp)
	jal drawInfoRect

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawV:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	li $a3, 1
	li $t5, 3
	addi $sp, $sp, -4 
	sw, $t5, 0($sp)
	jal drawInfoRect

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawR:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	li $a3, 1
	li $t5, 5
	addi $sp, $sp, -4 
	sw, $t5, 0($sp)
	jal drawInfoRect
	
	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawP:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	li $a3, 1
	li $t5, 5
	addi $sp, $sp, -4 
	sw, $t5, 0($sp)
	jal drawInfoRect

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawT:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1 1
	li $a3, 1
	li $t5, 5
	addi $sp, $sp, -4 
	sw, $t5, 0($sp)
	jal drawInfoRect

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra

drawS:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 4
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 4
	jal setAtInfoPos

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra


gameOverScreen:
	lw $a0, text1Color
	li $a1, 8
	li $a2, 7
	jal drawG

	lw $a0, text1Color
	li $a1, 12
	li $a2, 7
	jal drawA

	lw $a0, text1Color
	li $a1, 16
	li $a2, 7
	jal drawM

	lw $a0, text1Color
	li $a1, 22
	li $a2, 7
	jal drawE

	lw $a0, text1Color
	li $a1, 9
	li $a2, 13
	jal drawO

	lw $a0, text1Color
	li $a1, 13
	li $a2, 13
	jal drawV

	lw $a0, text1Color
	li $a1, 17
	li $a2, 13
	jal drawE

	lw $a0, text1Color
	li $a1, 21
	li $a2, 13
	jal drawR

	jal draw

	# Delay
	li $a0 47
	li $a1, 250
	lw $a2, deathI
	li $a3, 127
	li $v0, 33 
	syscall

	li $a0 150
	li $v0, 32 
	syscall 

	# Delay
	li $a0 39
	li $a1, 250
	lw $a2, deathI
	li $a3, 127
	li $v0, 33 
	syscall

	li $a0 150
	li $v0, 32 
	syscall 

	# Delay
	li $a0 39
	li $a1, 250
	lw $a2, deathI
	li $a3, 127
	li $v0, 33 
	syscall 

	# Press line

	lw $a0, text2Color
	li $a1, 4
	li $a2, 19
	jal drawP

	lw $a0, text2Color
	li $a1, 8
	li $a2, 19
	jal drawR

	lw $a0, text2Color
	li $a1, 12
	li $a2, 19
	jal drawE

	lw $a0, text2Color
	li $a1, 16
	li $a2, 19
	jal drawS

	lw $a0, text2Color
	li $a1, 20
	li $a2, 19
	jal drawS

	lw $a0, text2Color
	li $a1, 25
	li $a2, 19
	jal drawA

	lw $a0, text2Color
	li $a1, 2
	li $a2, 25
	jal drawT

	lw $a0, text2Color
	li $a1, 6
	li $a2, 25
	jal drawO

	lw $a0, text2Color
	li $a1, 12
	li $a2, 25
	jal drawR

	lw $a0, text2Color
	li $a1, 16
	li $a2, 25
	jal drawE

	lw $a0, text2Color
	li $a1, 20
	li $a2, 25
	jal drawS

	lw $a0, text2Color
	li $a1, 24
	li $a2, 25
	jal drawE

	lw $a0, text2Color
	li $a1, 28
	li $a2, 25
	jal drawT

	jal draw

	gameEndLoop:
	lw $t8, 0xffff0000
	beq $t8, 1, keyboardInputEnd
	keyboardInputEnd:
	lw $t2, 0xffff0004
	bne $t2, 0x61, gameEndLoop

	# Reset Lives
	la $t0, lives
	li $t4, 3
	sw $t4, 0($t0)

	# Reset score
	la $t0, score
	li $t4, 0
	sw $t4, 0($t0)

	jal clearInfoOverlay
	jal clearFrog
	jal clearEntityOverlay
	jal clearVictoryOverlay
	jal resetFrogPos
	
	jal main

updateHeartDisplay:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	
	jal clearInfoOverlay

	li $t9, 0 # Init counter
	heartDisplayLoopStart:
	lw $t0, lives
	beq $t0, $t9, heartDisplayLoopEnd
	sll $t8, $t9, 2
	li $t7, 2
	sll $t7, $t9, 1
	add $t8, $t8, $t7

	lw $a0, heartColor
	move $a1, $t8
	li $a2, 0
	jal drawHeart

	addi $t9, $t9, 1
	j heartDisplayLoopStart
	heartDisplayLoopEnd:

	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	jr $ra # Exit function

drawHeart:
	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
	move $t0, $a0
	move $t1, $a1
	move $t2, $a2

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 3
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 3
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 4
	addi $a2, $a2, 1
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 1
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 3
	addi $a2, $a2, 2
	jal setAtInfoPos

	move $a0, $t0
	move $a1, $t1
	move $a2, $t2
	addi $a1, $a1, 2
	addi $a2, $a2, 3
	jal setAtInfoPos

	lw $ra,  0($sp) 
	addi $sp, $sp, 4
	jr $ra



Exit:
	li $v0, 10 # terminate the program
	syscall
