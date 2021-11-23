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
## Colors ##
frogColor: .word 0x4fa64f
logColor: .word 0x742913
waterColor: .word 0x26b7ff
grassColor: .word 0xabd5ab
roadColor: .word 0xc5bda7
carColor: .word 0xdbbfd5
safeColor: .word 0xFFBF00
## Positions (x, y) 32 x 32 display ##
## Positiosn represent top right of sprite
frogX: .word 1
frogY: .word 2
## Other ##
displayAddress: .word 0x10008000 #Just use $gp
displayWidth: .word 32 # Width of display
displayHeight: .word 32 # Height of display
## Notes ##
# $a0 is reserved for color
####################################################################
	.text   
main:
	lw $t0, frogColor

	sw $t0, 0($gp)
	sw $t0, 4($gp)
	
	lw $a1, frogX
	lw $a2, frogY
	jal coordinateToAddress
	move $a3, $v0
	lw $a0, frogColor
	jal setPixel
	
	jal drawRegions
	j Exit

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
# $a1: xPos
# $a2: yPos
drawFrog:
	#

	jr $ra # return $v0


drawRegions:
############## Draw Start Region
	lw $a0, grassColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 28 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawRectangle
############## Draw Road
	lw $a0, roadColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 20 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 8 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawRectangle
############## Draw Safe Region
	lw $a0, safeColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 16 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 4 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawRectangle
############## Draw River Region
	lw $a0, waterColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 8 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 8 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawRectangle
############## Draw Goal Region
	lw $a0, grassColor # Load grass color
	li $a1, 0 # Set top left x
	li $a2, 0 # Set top left y
	lw, $a3, displayWidth # Set width
	li, $t0, 8 # Set height
	sw, $t0, 16($sp) # Load height into stack
	jal drawRectangle
	jr $ra

# void drawRectangle
	# Draw rectangle
	#
	# $a0: color
	# $a1: xPos (Top left corner)
	# $a2: yPos (Top left corner)
	# $a3: width
	# $16($sp): height
	# returns none
drawRectangle:
	lw $t5, 16($sp) # Load height from stack
	lw $t0, displayWidth # Load displayWidth
	lw $t7, displayHeight # Load displayHeight
 	
 	addi $sp, $sp, -4 
 	sw $ra, 0($sp) # Push $ra to stack
 	
	move $t1, $a1 # Save fixed initial xPos
	move $t2, $a2 # Save fixed initial yPos
	
	move $t3, $t1        # Initialize xPos counter
	move $t4, $t1        # Initialize rightmost position  
	add $t4, $t4, $a3
startRectLoop1:  
	beq $t3, $t4, endRectLoop1
	bge $t3, $t0, endRectLoop1 # Ensure xPos stays on screen
######################## Inner loop  
	move $t1, $t2        # Initialize yPos counter  
	move $t6, $t2        # Initialize bottommost position  
	add $t6, $t6, $t5
startRectLoop2:  
	beq $t1, $t6, endRectLoop2  
	bge $t1, $t7, endRectLoop2 # Ensure yPos stays on screen
  
	move $a1, $t3
	move $a2, $t1
	jal coordinateToAddress # convert pos to address ($v0 is now address)
	move $a3, $v0
	jal setPixel
  
	addi $t1, $t1, 1    # Increment yPos counter  
	b startRectLoop2  
endRectLoop2:  
######################## Inner loop  
	addi $t3, $t3, 1    # Increment xPos counter  
	b startRectLoop1
endRectLoop1:
	lw $ra,  0($sp) # Load $ra from stack
	addi $sp, $sp, 4
	
	jr $ra # Exit function


####################################################################
Exit:
	li $v0, 10 # terminate the program
	syscall
