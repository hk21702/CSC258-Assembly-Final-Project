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
## Positions (x, y) 32 x 32 display ##
## Positiosn represent top right of sprite
frogX: .word 1
frogY: .word 2
## Other ##
displayAddress: .word 0x10008000 #Just use $gp
regionHeight: 
	.text   
main:
	lw $t0, frogColor

	sw $t0, 0($gp)
	sw $t0, 4($gp)
	
	lw $a0, frogX
	lw $a1, frogY
	jal coordinateToAddress
	move $a0, $v0
	lw $a1, frogColor
	jal setPixel
	j Exit

# void setPixel (
	# set the pixel value at the position address to color
	# 
	# $a0: Position address
	# $a1: color
setPixel:
	sw $a1, ($a0) # Set address to color
	jr $ra	# return $v0
	
# .word coordianteToAddress
	# Convert coordiantes to bitmap display address
	#
	# $a0: xPos
	# $a1: yPos
	#
	# returns $v0: address of coordinates for the bitmap display
coordinateToAddress:
	# Shift to display pos
	sll $v0, $a1, 7 # Shift y height
	sll $a0, $a0, 2 # x * 4 (shift 2) shift x width
	add $v0, $v0, $a0 # Add x and y
	add $v0, $gp, $v0 # set $v0 to pixel address for bitmap display 
	
	jr $ra	# return $v0

# 
#
# $a0: xPos
# $a1: yPos
drawFrog:
	#

	jr $ra # return $v0


drawRegions:

Exit:
	li $v0, 10 # terminate the program
	syscall