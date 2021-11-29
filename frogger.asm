#####################################################################
#
# CSC258H5S Fall 2021 Assembly Final Project
# University of Toronto, St. George
#
# Student: Name, Student Number
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
# - Milestone 1/2/3/4/5 (choose the one the applies)
#
# Which approved additional features have been implemented?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
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
## Dynamic Positions (x, y) 32 x 32 display ##
## Positiosn represent top right of sprite
frogX: .word 16
frogY: .word 28
setOverlay: .space 4096 # 32 * 32 * 4
entityOverlay: .space 4096
## Fixed Positions
cars1Region: .word 20
cars2Region: .word 24
logs1Region: .word 8
logs2Region: .word 12
regionHeight: .word 4
frogWidth: .word 4
frogHeight: .word 4
## 
car1Counter: .word 2
car2Counter: .word 4
logs1Counter: .word 2
logs2Counter: .word 4
cars1State: .space 4
cars2State: .space 4
logs1State: .space 4
logs2State: .space 4
frameDelay: .word 25
frameCounter: .word 0
shiftIntervalMax: .word 8
shiftIntervalMin: .word 4
## Other ##
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
	
	gameLoop:
	# Tick framecounter
	la $t0, frameCounter
	lw $t4, 0($t0)
	addi $t4, $t4, 1
	sw $t4, 0($t0)

	# Check if hazard change appropriate
	lw $t0, frameCounter
	lw $t1, frameDelay
	blt $t0, $t1, gameLoopEnd
	### Update Hazards ###
	# Reset frame counter
	la $t0, frameCounter
	li $t4, 0
	sw $t4, 0($t0)

	jal shiftLogs1
	jal shiftLogs2

	gameLoopEnd:
	lw $t8, 0xffff0000
	beq $t8, 1, keyboardInput
	jal clearEntityOverlay
	jal drawFrog
	jal draw

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
		addi $t4, $t4, -4
		sw $t4, 0($t0)
		wExit:
		lw $ra,  0($sp) 
		addi $sp, $sp, 4
		jr $ra	

	respondA:

		la $t0, frogX
		lw $t4, 0($t0)
		li $t1, 3 
		ble $t4, $t1, aExit
		addi $t4, $t4, -4
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
		sll $t2, $t2, 1
		subi $t2, $t2, 1
		sub $t1, $t1, $t2
		bge $t4, $t1, dExit
		addi $t4, $t4, 4
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
	beq $v0, $0, drawSkip
	move $a0, $v0 # Override color

	drawSkip:
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
 	sw $t0, 0($sp) # Push $t0 to stack
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect
	lw $t0,  0($sp) # Load $t0 from stack
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
 	sw $t0, 0($sp) # Push $t0 to stack
	sw, $t2, 16($sp) # Load height into stack
	jal drawSetRect
	lw $t0,  0($sp) # Load $t0 from stack
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





##


# $a1 -> upperbound
# $a2 -> lowerbound
getRandomNum:
	li $v0, 42
	li $a0, 0
	sub $a1, $a1, $a2 # Shift upper bound
	syscall
	add $v0, $a0, $a2 # Apply lower bound
	jr $ra # Exit function


Exit:
	li $v0, 10 # terminate the program
	syscall
