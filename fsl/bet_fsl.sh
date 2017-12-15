#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 09/22/2014 By: Evan Layher (evan.layher@psych.ucsb.edu)
# Revised: 11/11/2015 By: Evan Layher (3.0) mac and linux compatible
# Revised: 04/12/2016 By: Evan Layher (3.1) allow paths with spaces (minor updates)
# Revised: 02/16/2017 By: Evan Layher (3.2) gzip nifti files and minor updates
# Revised: 08/18/2017 By: Evan Layher (3.3) compatible with fsleyes (FSL 5.0.10+)
# Revised: 11/01/2017 By: Evan Layher (3.4) Robust BET (-R option)
# Revised: 12/15/2017 By: Evan Layher (3.5) More options (c,r,B,R,S); minor updates
#--------------------------------------------------------------------------------------#
# Brain extract structural mri images using FSL's bet function

## --- LICENSE INFORMATION --- ##
## bet_fsl.sh is the proprietary property of The Regents of the University of California ("The Regents.")

## Copyright © 2014-17 The Regents of the University of California, Davis campus. All Rights Reserved.

## Redistribution and use in source and binary forms, with or without modification, are permitted by nonprofit, 
## research institutions for research use only, provided that the following conditions are met:

## • Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer
## • Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
##	in the documentation and/or other materials provided with the distribution. 
## • The name of The Regents may not be used to endorse or promote products derived from this software without specific prior written permission.

## The end-user understands that the program was developed for research purposes and is advised not to rely exclusively on the program for any reason.

## THE SOFTWARE PROVIDED IS ON AN "AS IS" BASIS, AND THE REGENTS HAVE NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
## THE REGENTS SPECIFICALLY DISCLAIM ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, 
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
## IN NO EVENT SHALL THE REGENTS BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES, 
## INCLUDING BUT NOT LIMITED TO  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, LOSS OF USE, DATA OR PROFITS, OR BUSINESS INTERRUPTION, 
## HOWEVER CAUSED AND UNDER ANY THEORY OF LIABILITY WHETHER IN CONTRACT, STRICT LIABILITY OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## If you do not agree to these terms, do not download or use the software.  
## This license may be modified only in a writing signed by authorized signatory of both parties.

## For commercial license information please contact copyright@ucdavis.edu.
## --------------------------- ##

#-------------------------------- VARIABLES --------------------------------#
default_f='0.50'	# '0.50': Default f value (Range 0 to 1)
default_g='0.00'	# '0.00': Default g value (Range -1 to 1)

default_bet_name='_brain'  # If output unspecified add this to input filename
default_opt_name='default' # Text display for default values

b_exp='bias field & neck cleanup' # -B option explanation
r_exp='robust centre estimation'  # -R option explanation
s_exp='eye & optic nerve cleanup' # -S option explanation

nifti_exts=('.nii' '.nii.gz') # Input file must have nifti extension
zip_ext='.nii.gz' # '.nii.gz' gzip files that lack this extension
#--------------------------- DEFAULT SETTINGS ------------------------------#
text_editors=('kwrite' 'kate' 'gedit' 'open -a /Applications/BBEdit.app' 'open') # GUI text editor commands in preference order

IFS_old="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (useful when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
usage () { # Help message: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: Brain extract and view images with FSL's '${gre}bet${whi}' function
     
${ora}USAGE${whi}: Specify input and output (${ora}optional${whi}) nifti files
 [${ora}1${whi}] ${gre}input.nii.gz output.nii.gz${whi}
 [${ora}2${whi}] ${gre}input.nii.gz${whi} # outputs input${default_bet_name}${zip_ext}
     
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-B${whi}   ${b_exp}
 ${pur}-c${whi}   Input X,Y,Z value of center voxel
 [${ora}3${whi}] ${gre}input.nii.gz ${pur}-c ${ora}31 31 23${whi}
 ${pur}-cs${whi}  Prevent screen from clearing before script processes
 ${pur}-f${whi}   Input f value (0 - 1)
 [${ora}4${whi}] ${gre}input.nii.gz output.nii.gz ${pur}-f ${ora}0.5${whi}
 ${pur}-g${whi}   Input g value (-1 - 1)
 [${ora}5${whi}] ${gre}input.nii.gz output.nii.gz ${pur}-g ${ora}0${whi}
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-r${whi}   Input radius of head (mm)
 [${ora}6${whi}] ${gre}input.nii.gz ${pur}-r ${ora}80${whi}
 ${pur}-R${whi}   ${r_exp}
 ${pur}-S${whi}   ${s_exp}
 
${ora}DEFAULT SETTINGS${whi}:
f value     : ${gre}${default_f}${whi}
g value     : ${gre}${default_g}${whi}

${ora}REFERENCE: ${gre}http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET${whi}
     
${ora}VERSION: ${gre}${version}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm
} # usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version='3.5' # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
b_opt='no'            # 'no' : Bet option '-B'           [INPUT: '-B']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
r_opt='no'            # 'no' : Bet option '-R'           [INPUT: '-R']
s_opt='no'            # 'no' : Bet option '-S'           [INPUT: '-S']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')

read_input_file='yes' # 'yes': Must input nifti file
read_output_file='no' # 'no' : Must input one output file
#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate inputs
	if [ "${1}" == '-B' 2>/dev/null ] || [ "${1}" == '-c' 2>/dev/null ] || \
	   [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-f' 2>/dev/null ] || \
	   [ "${1}" == '-g' 2>/dev/null ] || [ "${1}" == '-h' 2>/dev/null ] || \
	   [ "${1}" == '--help' 2>/dev/null ] || [ "${1}" == '-nc' 2>/dev/null ] || \
	   [ "${1}" == '-nm' 2>/dev/null ] || [ "${1}" == '-o' 2>/dev/null ] || \
	   [ "${1}" == '--open' 2>/dev/null ] || [ "${1}" == '-r' 2>/dev/null ] || \
	   [ "${1}" == '-R' 2>/dev/null ] || [ "${1}" == '-S' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ "${c_in}" == 'yes' 2>/dev/null ]; then # -c
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -ge '0' 2>/dev/null ]; then
			c_vals+=("${1}") # Input: 0+ (Coordinates for center voxel of head)
		else # invalid
			bad_inputs+=("-c:${1}")
		fi
		
		if [ "${#c_vals[@]}" -ge '3' ]; then # Requires 3 inputs
			c_in='no' # Stop collecting values for option
		fi
	elif [ "${f_in}" == 'yes' 2>/dev/null ]; then # -f
		check_f=$(echo "${1}" |awk '{print ($1 >= 0 && $1 <= 1)}') # 1 = valid, 0 = invalid
		if [ "${check_f}" -eq '1' 2>/dev/null ]; then # Returned 1 (valid)
			f_val="${1}" # Input: (0 - 1)
		else # Returned 0 (invalid)
			bad_inputs+=("-f:${1}")
		fi
		
		f_in='no' # Stop collecting values for option
	elif [ "${g_in}" == 'yes' 2>/dev/null ]; then # -g
		check_g=$(echo "${1}" |awk '{print ($1 >= -1 && $1 <= 1)}') # 1 = valid, 0 = invalid
		if [ "${check_g}" -eq '1' 2>/dev/null ]; then # Returned 1 (valid)
			g_val="${1}" # Input: (-1 - 1)
		else # Returned 0 (invalid)
			bad_inputs+=("-g:${1}")
		fi
		
		g_in='no' # Stop collecting values for option
	elif [ "${r_in}" == 'yes' 2>/dev/null ]; then # -r
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -ge '0' 2>/dev/null ]; then
			r_val="${1}" # Input: 1+ (Radius of head in mm)
		else # invalid
			bad_inputs+=("-r:${1}")
		fi
		
		r_in='no' # Stop collecting values for option
	elif [ "${1:0:1}" == '-' ]; then # Invalid option (Do not use as filenames)
		bad_inputs+=("INVALID-OPTION:${1}")
	elif [ -f "${1}" ] || [ -f "${1}${zip_ext}" ] && [ "${read_input_file}" == 'yes' 2>/dev/null ]; then
		if [ -f "${1}" ]; then
			input_file="${1}"
		else # Add nifti extension
			input_file="${1}${zip_ext}"
		fi
		
		proceed='no'
		for i in ${!nifti_exts[@]}; do # Loop thru nifti extensions
			nifti_ext="${nifti_exts[${i}]}"
			check_nii=($(echo "${input_file}" |grep "${nifti_ext}$")) # Must be nifti file
			if [ "${#check_nii[@]}" -gt '0' ]; then
				input_file=$(mac_readlink "${input_file}") # similar to 'readlink -f' in linux
				
				# gzip nifti file
				input_filename=$(echo "${input_file}" |sed "s/${nifti_ext}$/${zip_ext}/g")
				gzip "${input_file}" 2>/dev/null # gzip nifti file
				
				if ! [ -f "${input_filename}" ]; then # If unforeseen error occurred
					bad_inputs+=("FILE-NOT-ZIPPED:${input_file}")
				else
					input_file="${input_filename}"
				fi
				
				proceed='yes'
				break # break loop when nifti extension is identified
			fi
		done # for i in ${!nifti_exts[@]}
		
		if [ "${proceed}" == 'no' 2>/dev/null ]; then
			bad_inputs+=("invalid-input-file:${1}")
		fi
		
		read_input_file='no'   # Only read in one input file
		read_output_file='yes' # Read output file
	elif [ "${read_output_file}" == 'yes' 2>/dev/null ]; then
		temp_outfile="${1}"
		for i in ${!nifti_exts[@]}; do
			nifti_ext="${nifti_exts[${i}]}"
			check_nii=($(echo "${1}" |grep "${nifti_ext}$")) # Check nifti extension
			
			if [ "${#check_nii[@]}" -gt '0' ]; then # Remove nifti extension from filename
				temp_outfile=$(echo "${temp_outfile}" |sed "s/${nifti_ext}$//g")
				break # break loop if nifti extension is identified
			fi
		done # for i in ${!nifti_exts[@]}
		
		output_file=$(mac_readlink "${temp_outfile}${zip_ext}") # End file with zipped extension
		read_output_file='no' # Only read in one output file
	else # Invalid input
		bad_inputs+=("${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	# Reset values
	c_in='no'
	f_in='no'
	g_in='no'
	r_in='no'
	
	if [ "${1}" == '-B' ]; then
		b_opt='yes'          # Activate '-B' option
	elif [ "${1}" == '-c' ]; then
		c_in='yes'           # Read in 'c' values
	elif [ "${1}" == '-cs' ]; then
		clear_screen='no'    # Do NOT clear screen at start
	elif [ "${1}" == '-f' ]; then
		f_in='yes'           # Read in 'f' value
	elif [ "${1}" == '-g' ]; then
		g_in='yes'           # Read in 'g' value
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'  # Display help message
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no' # Do NOT display messages in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'    # Do NOT display exit message
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'    # Open this script
	elif [ "${1}" == '-r' ]; then
		r_in='yes'           # Read in 'r' value
	elif [ "${1}" == '-R' ]; then
		r_opt='yes'          # Activate '-R' option
	elif [ "${1}" == '-S' ]; then
		s_opt='yes'          # Activate '-S' option
	else # if option is undefined (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

bet_image () { # bet structural images
	extra_options=() # Reset array
	
	# Save previous values to display during 'redo_bet' function
	prev_f="${f_val}"
	prev_g="${g_val}"
	prev_c="${default_opt_name}" # Changes later if specified
	prev_r="${default_opt_name}" # Changes later if specified
	prev_b_opt="${b_opt}"
	prev_r_opt="${r_opt}"
	prev_s_opt="${s_opt}"
	
	clear
	echo "${gre}CREATING: ${ora}${output_file}${whi}"
	echo "${ora}F value: ${gre}${f_val}${whi}" # -f
	echo "${ora}G value: ${gre}${g_val}${whi}" # -g
	
	if [ "${#c_vals[@]}" -eq '3' ]; then # -c
		extra_options+=($(printf "%s${IFS}" '-c' ${c_vals[@]}))
		prev_c=$(echo ${c_vals[@]})
		echo "${ora}Center voxel: ${gre}${c_vals[0]} ${c_vals[1]} ${c_vals[2]}${whi}"
	fi
	
	if ! [ -z "${r_val}" ]; then # -r
		extra_options+=($(printf "%s${IFS}" '-r' "${r_val}"))
		prev_r="${r_val}"
		echo "${ora}Head radius (mm): ${gre}${r_val}${whi}"
	fi
	
	if [ "${b_opt}" == 'yes' ]; then # -B
		extra_options+=('-B')
		echo "${pur}-B: ${gre}${b_exp}${whi}"
	fi
	
	if [ "${r_opt}" == 'yes' ]; then # -R
		extra_options+=('-R')
		echo "${pur}-R: ${gre}${r_exp}${whi}"
	fi
	
	if [ "${s_opt}" == 'yes' ]; then # -S
		extra_options+=('-S')
		echo "${pur}-S: ${gre}${s_exp}${whi}"
	fi
	
	"${FSLDIR}/bin/fslreorient2std" "${input_file}" "${input_file}" & # Reorient brain to standard
	wait # Prevent corrupting nifti file
	eval "${FSLDIR}/bin/bet ${input_file} ${output_file} -g ${g_val} -f ${f_val} ${extra_options[@]} &" # Brain extraction
	wait # Prevent corrupting nifti file
	"${fsl_view_cmd}" "${output_file}" "${input_file}" "${output_file}" "${cm_option}" 2>/dev/null
	clear
	redo_bet
} # bet_image

check_name_space () { # Exit script if filename contains a space
	for file_inputs; do
		check_space=($(echo "${file_inputs}" |grep ' '))
		if [ "${#check_space[@]}" -gt '0' ]; then
			echo "${red}FILENAMES CANNOT CONTAIN SPACES: ${ora}${file_inputs}${whi}"
			exit_message 99 -nh -nm
		fi
	done
} # check_name_space

color_formats () { # Print colorful terminal text
	if [ "${activate_colors}" == 'yes' 2>/dev/null ]; then
		whi=$(tput setab 0; tput setaf 7) # Black background, white text
		red=$(tput setab 0; tput setaf 1) # Black background, red text
		ora=$(tput setab 0; tput setaf 3) # Black background, orange text
		gre=$(tput setab 0; tput setaf 2) # Black background, green text
		blu=$(tput setab 0; tput setaf 4) # Black background, blue text
		pur=$(tput setab 0; tput setaf 5) # Black background, purple text
		formatreset=$(tput sgr0)          # Reset to default terminal settings
	fi
} # color_formats

mac_readlink () { # Get absolute path of a file (mac and linux compatible)
	dir_mac=$(dirname "${1}")   # Directory path
	file_mac=$(basename "${1}") # Filename
	wd_mac=$(pwd) # Working directory path

	if [ -d "${dir_mac}" ]; then
		cd "${dir_mac}"
		echo "$(pwd)/${file_mac}" # Print full path
		cd "${wd_mac}" # Change back to original directory
	else
		echo "${1}" # Print input
	fi
} # mac_readlink

open_text_editor () { # Opens input file in background (GUI text editors only)
	open_file="${1}"  # Input file
	valid_editor='no' # Remains 'no' until command is valid
	
	if [ -f "${open_file}" ]; then # If input file exists
		for i in ${!text_editors[@]}; do # Loop through indices
			eval "${text_editors[${i}]} ${open_file} 2>/dev/null &" # eval for complex commands
			pid="$!" # Background process ID
			check_pid=($(ps "${pid}" |grep "${pid}")) # Check if pid is running
			
			if [ "${#check_pid[@]}" -gt '0' ]; then
				valid_editor='yes'
				break
			fi # Break loop when valid command is found
		done

		if [ "${valid_editor}" == 'no' 2>/dev/null ]; then
			echo "${red}NO VALID TEXT EDITOR COMMANDS IN ${ora}text_editors ${red}ARRAY:${whi}"
			printf "${ora}%s${IFS}${whi}" ${text_editors[@]}
			exit_message 99 -nh -nm
		fi
	else # Missing input file
		echo "${red}MISSING FILE: ${ora}${open_file}${whi}"
	fi # if [ -f "${open_file}" ]; then
} # open_text_editor

redo_bet () { # Redo bet with new parameters
	echo "${gre}CREATED: ${ora}${output_file}${whi}"
	echo "${ora}[${gre}a${ora}] ACCEPT BET IMAGE${whi}"
	echo "${ora}[${gre}v${ora}] VIEW BET IMAGE${whi}"
	echo "${ora}[${gre}r${ora}] REDO BET WITH SPECIFIED PARAMETERS${whi}"
	
	if [ "${f_val}" == "${prev_f}" 2>/dev/null ]; then # -f
		echo "${blu}[${whi}1${blu}] ${pur}-f ${ora}${f_val}${whi}"
	else # Display previous value
		echo "${blu}[${whi}1${blu}] ${pur}-f ${gre}${f_val} ${whi}(PREVIOUS VALUE: ${ora}${prev_f}${whi})"
	fi
	
	if [ "${g_val}" == "${prev_g}" 2>/dev/null ]; then # -g
		echo "${blu}[${whi}2${blu}] ${pur}-g ${ora}${g_val}${whi}"
	else # Display previous value
		echo "${blu}[${whi}2${blu}] ${pur}-g ${gre}${g_val} ${whi}(PREVIOUS VALUE: ${ora}${prev_g}${whi})"
	fi
	
	if [ "${#c_vals[@]}" -ne '3' ]; then # Setup '-c' option
		c_disp="${default_opt_name}"
	else
		c_disp=$(echo ${c_vals[@]})
	fi
	
	if [ "${c_disp}" == "${prev_c}" 2>/dev/null ]; then # -c
		echo "${blu}[${whi}3${blu}] ${pur}-c ${ora}Center voxel: ${c_disp}${whi}"
	else # Display previous value
		echo "${blu}[${whi}3${blu}] ${pur}-c ${ora}Center voxel: ${gre}${c_disp} ${whi}(PREVIOUS VALUE: ${ora}${prev_c}${whi})"
	fi
	
	if [ -z "${r_val}" ]; then # Setup '-r' option
		r_disp="${default_opt_name}"
	else
		r_disp="${r_val}"
	fi
	
	if [ "${r_disp}" == "${prev_r}" 2>/dev/null ]; then # -r
		echo "${blu}[${whi}4${blu}] ${pur}-r ${ora}Head radius (mm): ${r_disp}${whi}"
	else # Display previous value
		echo "${blu}[${whi}4${blu}] ${pur}-r ${ora}Head radius (mm): ${gre}${r_disp} ${whi}(PREVIOUS VALUE: ${ora}${prev_r}${whi})"
	fi
	
	if [ "${prev_b_opt}" == "${b_opt}" 2>/dev/null ]; then # -B
		echo "${blu}[${whi}5${blu}] ${pur}-B ${ora}${b_exp} (${b_opt})${whi}"
	else # Display previous value
		echo "${blu}[${whi}5${blu}] ${pur}-B ${ora}${b_exp} (${gre}${b_opt}${ora})${whi}"
	fi
	
	if [ "${prev_r_opt}" == "${r_opt}" 2>/dev/null ]; then # -R
		echo "${blu}[${whi}6${blu}] ${pur}-R ${ora}${r_exp} (${r_opt})${whi}"
	else # Display previous value
		echo "${blu}[${whi}6${blu}] ${pur}-R ${ora}${r_exp} (${gre}${r_opt}${ora})${whi}"
	fi
	
	if [ "${prev_s_opt}" == "${s_opt}" 2>/dev/null ]; then # -S
		echo "${blu}[${whi}7${blu}] ${pur}-S ${ora}${s_exp} (${s_opt})${whi}"
	else # Display previous value
		echo "${blu}[${whi}7${blu}] ${pur}-S ${ora}${s_exp} (${gre}${s_opt}${ora})${whi}"
	fi
	
	printf "${ora}INPUT NUMBER(S) TO CHANGE PARAMETERS OR SPECIFY ACTION:${whi}"
	
	read -r bet_option
	bet_options=($(echo "${bet_option}" |tr ' ' "${IFS}" |sort -u)) # Convert to array

	# Reset values
	invalid_inputs=() # Reset array
	change_par='no' # Change parameter if number
	acpt_img='no'
	view_img='no'
	redo_img='no'
	
	for i in ${!bet_options[@]}; do # Loop thru inputs
		bet_option="${bet_options[${i}]}"
		
		if [ "${bet_option}" -eq '1' 2>/dev/null ]; then # Change -f
			change_par='yes'
			valid_f='no'
			
			clear
			until [ "${valid_f}" == 'yes' 2>/dev/null ]; do # Input: 0 - 1
				echo "${red}SMALLER ${gre}f${ora} values produce ${red}LARGER${ora} brain outputs${whi}"
				echo "${ora}PREVIOUS F VALUE: ${gre}${prev_f}${whi}"
				printf "${ora}INPUT NEW F VALUE (${gre}0 ${ora}to ${gre}1${ora}):${whi}"
				read -r new_f
				check_f=$(echo "${new_f}" |awk '{print ($1 >= 0 && $1 <= 1)}') # (0 - 1)
				if [ "${check_f}" -eq '1' 2>/dev/null ]; then
					f_val="${new_f}"
					valid_f='yes'
				else
					invalid_msg "${new_f}"
				fi
			done # until [ "${valid_f}" == 'yes' 2>/dev/null ]
		elif [ "${bet_option}" -eq '2' 2>/dev/null ]; then # Change -g
			change_par='yes'
			valid_g='no'
			
			clear
			until [ "${valid_g}" == 'yes' 2>/dev/null ]; do # Input: -1 - 1
				echo "${red}POSITIVE ${gre}g${ora} values produce ${red}LARGER${ora} brain outputs on ${red}BOTTOM${ora}, ${red}SMALLER${ora} on ${red}TOP${whi}"
				echo "${ora}PREVIOUS G VALUE: ${gre}${prev_g}${whi}"
				printf "${ora}INPUT NEW G VALUE (${gre}-1 ${ora}to ${gre}1${ora}):${whi}"
				read -r new_g
				check_g=$(echo "${new_g}" |awk '{print ($1 >= -1 && $1 <= 1)}') # (-1 - 1)
				if [ "${check_g}" -eq '1' 2>/dev/null ]; then
					g_val="${new_g}"
					valid_g='yes'
				else
					invalid_msg "${new_g}"
				fi
			done # until [ "${valid_g}" == 'yes' 2>/dev/null ]
		elif [ "${bet_option}" -eq '3' 2>/dev/null ]; then # Change -c
			change_par='yes'
			valid_c='no'
			
			clear
			until [ "${valid_c}" == 'yes' 2>/dev/null ]; do # Input: 3 positive integers
				echo "${ora}PREVIOUS CENTER COORDINATE: ${gre}${prev_c}${whi}"
				echo "${ora}PRESS ${gre}enter ${ora}FOR DEFAULT${whi}"
				printf "${ora}INPUT X, Y, Z CENTER VOXEL COORDINATE (e.g. ${gre}31 31 23${ora}):${whi}"
				read -r new_c
				
				if [ -z "${new_c}" ]; then
					valid_c='yes'
					c_vals=() # Set to default
				else
					check_c=($(echo "${new_c}" |tr ' ' "${IFS}")) # 3 positive integers
					if [ "${#check_c[@]}" -eq '3' ]; then
						valid_c='yes'
						c_vals=() # Reset array
					
						for j in ${!check_c[@]}; do
							in_c="${check_c[${j}]}"
							if [ "${in_c}" -eq "${in_c}" 2>/dev/null ] && [ "${in_c}" -ge '0' 2>/dev/null ]; then
								c_vals+=("${in_c}")
							else
								valid_c='no'
							fi
						done
					fi
				fi # if [ -z "${new_c}" ]
				
				if ! [ "${valid_c}" == 'yes' ]; then
					echo "${red}MUST INPUT 3 POSITIVE INTEGERS${whi}"
					invalid_msg ${check_c[@]}
				fi
			done # until [ "${valid_g}" == 'yes' 2>/dev/null ]
			
		elif [ "${bet_option}" -eq '4' 2>/dev/null ]; then # Change -r
			change_par='yes'
			valid_r='no'
			
			clear
			until [ "${valid_r}" == 'yes' 2>/dev/null ]; do # Input: Positive integer
				echo "${ora}PREVIOUS HEAD RADIUS (mm): ${gre}${prev_r}${whi}"
				echo "${ora}PRESS ${gre}enter ${ora}FOR DEFAULT${whi}"
				printf "${ora}INPUT HEAD RADIUS (mm):${whi}"
				read -r new_r
				
				if [ -z "${new_r}" ]; then
					valid_r='yes'
					r_val='' # Set to default
				else
					if [ "${new_r}" -eq "${new_r}" 2>/dev/null ] && [ "${new_r}" -gt '0' 2>/dev/null ]; then
						valid_r='yes'
						r_val="${new_r}"
					else
						echo "${red}MUST INPUT POSITIVE INTEGER${whi}"
						invalid_msg "${new_r}"
					fi
				fi # if [ -z "${new_r}" ]
			done # until [ "${valid_g}" == 'yes' 2>/dev/null ]
			
		elif [ "${bet_option}" -eq '5' 2>/dev/null ]; then # Change -B
			change_par='yes'
			if [ "${b_opt}" == 'no' ]; then
				b_opt='yes'
			else
				b_opt='no'
			fi
		elif [ "${bet_option}" -eq '6' 2>/dev/null ]; then # Change -R
			change_par='yes'
			if [ "${r_opt}" == 'no' ]; then
				r_opt='yes'
			else
				r_opt='no'
			fi
		elif [ "${bet_option}" -eq '7' 2>/dev/null ]; then # Change -S
			change_par='yes'
			if [ "${s_opt}" == 'no' ]; then
				s_opt='yes'
			else
				s_opt='no'
			fi
		elif [ "${bet_option}" == 'a' 2>/dev/null ] || [ "${bet_option}" == 'A' 2>/dev/null ]; then
			acpt_img='yes'
		elif [ "${bet_option}" == 'v' 2>/dev/null ] || [ "${bet_option}" == 'V' 2>/dev/null ]; then
			view_img='yes'
		elif [ "${bet_option}" == 'r' 2>/dev/null ] || [ "${bet_option}" == 'R' 2>/dev/null ]; then
			redo_img='yes'
		else # Collect invalid inputs
			invalid_inputs+=("${bet_option}")
		fi	
	done # for i in ${!bet_options[@]}
	
	if [ "${#invalid_inputs[@]}" -gt '0' ]; then
		invalid_msg ${invalid_inputs[@]}
		redo_bet
	fi
	
	if [ "${change_par}" == 'yes' 2>/dev/null ]; then # Inputs: 1-7
		clear
		redo_bet
	elif [ "${view_img}" == 'yes' ]; then # Input: v
		"${fsl_view_cmd}" "${output_file}" "${input_file}" "${output_file}" "${cm_option}" 2>/dev/null
		clear # View brain extraction
		redo_bet
	elif [ "${acpt_img}" == 'yes' 2>/dev/null ] && [ "${redo_img}" == 'yes' 2>/dev/null ]; then
		echo "${red}CANNOT INPUT BOTH ${pur}a ${red}AND ${pur}r ${red}OPTIONS${whi}"
		redo_bet # Cannot differentiate 'a' or 'r' option
	elif [ "${acpt_img}" == 'yes' 2>/dev/null ]; then # Input: a
		exit_message 0 # Close script
	elif [ "${redo_img}" == 'yes' 2>/dev/null ]; then # Input: r
		bet_image # BET with new parameters
	else
		invalid_msg ${bet_options[@]}
	fi # if [ "${change_par}" == 'yes' 2>/dev/null ]
} # redo_bet

vital_file () { # Exit script if missing file
	for vitals; do
		if ! [ -e "${vitals}" 2>/dev/null ]; then
			bad_files+=("${vitals}")
		fi
	done
	
	if [ "${#bad_files[@]}" -gt '0' ]; then
		echo "${red}MISSING ESSENTIAL FILE(S):${whi}"
		printf "${pur}%s${IFS}${whi}" ${bad_files[@]}
		exit_message 98 -nh -nm
	fi
} # vital_file

#-------------------------------- MESSAGES ---------------------------------#
exit_message () { # Script exit message
	if [ -z "${1}" 2>/dev/null ] || ! [ "${1}" -eq "${1}" 2>/dev/null ]; then
		exit_type='0'
	else
		exit_type="${1}"
	fi
	
	if [ "${exit_type}" -ne '0' ]; then
		suggest_help='yes'
	fi
	
	for exit_inputs; do
		if [ "${exit_inputs}" == '-nh' 2>/dev/null ]; then
			suggest_help='no'
		elif [ "${exit_inputs}" == '-nm' 2>/dev/null ]; then
			display_exit='no'
		fi
	done
	
	wait # Wait for background processes to finish

	# Suggest help message
	if [ "${suggest_help}" == 'yes' 2>/dev/null ]; then
		echo "${ora}FOR HELP: ${gre}${script_path} -h${whi}"
	fi
	
	# Display exit message
	if ! [ "${display_exit}" == 'no' 2>/dev/null ]; then # Exit message
		echo "${pur}EXITING: ${ora}${script_path}${whi}"
	fi
	
	printf "${formatreset}\n"
	IFS="${IFS_old}" # Reset IFS
	exit "${exit_type}"
} # exit_message

control_c () { # Wait for background processes to finish
	all_jobs=($(jobs -p))
	if [ "${#all_jobs[@]}" -gt '0' ]; then
		echo "${red}FINISHING BET PROCESSING BEFORE CRASHING TO PREVENT FILE CORRUPTION${whi}"
		wait
	fi

	cd "${wd}" # Change back to working directory
	IFS="${IFS_original}" # Reset IFS
	printf '\n' # print new line
	exit_message 0
} # control_c

invalid_msg () { # Displays invalid input message
	clear
	echo "${red}INVALID INPUT:${whi}"
	printf "${ora}%s${IFS}${whi}" ${@}
} # invalid_msg

#---------------------------------- CODE -----------------------------------#
trap control_c SIGINT 2>/dev/null # Stops ctrl + c crash
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

if [ -z "${FSLDIR}" ]; then # Check FSL directory exists
	echo "${gre}\$FSLDIR ${red}NOT DEFINED${whi}"
	echo "${red}MUST '${gre}source ${ora}fsl.sh${red}' SCRIPT BEFORE PROCESSING${whi}"
	exit_message 1
fi

vital_file "${FSLDIR}/bin/bet" "${FSLDIR}/bin/fslreorient2std" # Make sure files exist

if [ -f "${FSLDIR}/bin/fsleyes" ]; then
	fsl_view_cmd="${FSLDIR}/bin/fsleyes" # Use fsleyes (5.0.10+)
	cm_option='-cm red' # Red color map option
elif [ -f "${FSLDIR}/bin/fslview" ]; then
	fsl_view_cmd="${FSLDIR}/bin/fslview" # Use fslview (5.0.9 and below)
	cm_option='-l Red' # Red color map option
else
	echo "${red}MISSING ${ora}fslview ${red}AND ${ora}fsleyes${whi}"
	exit_message 2
fi

base_script=$(basename "${script_path}")
echo "RUNNING: ${base_script}"
for inputs; do # Read through all inputs
	option_eval "${inputs}"
done

if ! [ "${clear_screen}" == 'no' 2>/dev/null ]; then
	clear     # Clears screen unless input option: '-cs'
fi

color_formats # Activate or prevent colorful output

# Display help message or open script
if [ "${activate_help}" == 'yes' 2>/dev/null ]; then # '-h' or '--help'
	usage # Display help message
elif [ "${open_script}" == 'yes' 2>/dev/null ]; then # '-o' or '--open'
	open_text_editor "${script_path}" # Open script
	exit_message 0 -nm
fi

# Exit script if invalid inputs
if [ "${#bad_inputs[@]}" -gt '0' ]; then
	invalid_msg ${bad_inputs[@]}
	exit_message 3
elif [ -z "${input_file}" ]; then  # Input file must be specified
	echo "${red}MUST SPECIFY NIFTI INPUT FILE${whi}"
	exit_message 4
elif [ "${#c_vals[@]}" -gt '0' ]; then # -c
	if [ "${#c_vals[@]}" -ne '3' ]; then # There must be 3 inputs if '-c' option
		echo "${red}ERROR: ${pur}-c ${ora}OPTION REQUIRES 3 INTEGER INPUTS${whi}"
		for i in ${!c_vals[@]}; do # Loop thru '-c' option inputs
			c_count=$((${i} + 1))
			echo "${blu}[${ora}${c_count}${blu}] ${gre}${c_vals[${i}]}${whi}"
		done
		exit_message 5
	fi
fi # if [ "${#bad_inputs[@]}" -gt '0' ]

if [ -z "${output_file}" ]; then # If output file is unspecified give default name
	output_file=$(echo "${input_file}" |sed "s/${zip_ext}$//g")"${default_bet_name}${zip_ext}"
fi # if [ "${#bad_inputs[@]}" -gt '0' ]

# Check if user is using a filename with default brain extracted name
bet_ext="${default_bet_name}${zip_ext}"
check_bet_input=($(echo "${input_file}" |grep "${bet_ext}$"))
if [ "${#check_bet_input[@]}" -gt '0' ]; then # Exit if input file has default BET ending
	echo "${red}INPUT FILENAME HAS BRAIN EXTRACTED NAME${whi}"
	echo "${whi}"$(basename "${input_file}" |sed "s,${bet_ext},${pur}${bet_ext},g")"${whi}"
	exit_message 6
fi

#-----FSL throws errors if filepath has whitespace: Trying work around [START]-----#
check_name_space $(basename "${input_file}") $(basename "${output_file}")
check_in_space=($(echo "${input_file}" |grep ' '))
check_out_space=($(echo "${output_file}" |grep ' '))
wd=$(pwd) # Change directories if path(s) contain spaces
if [ "${#check_in_space[@]}" -gt '0' ] && [ "${#check_out_space[@]}" -gt '0' ]; then
	if [ "${input_file}" == "${output_file}" 2>/dev/null ]; then
		common_dir=$(dirname "${input_file}") # If files are the same
	else
		check_in_dir=($(echo "${input_file}" |sed "s@/@\\${IFS}@g"))
		check_out_dir=($(echo "${output_file}" |sed "s@/@\\${IFS}@g"))
		common_dir='/' # Directory that is common to both files
		for i in ${!check_in_dir[@]}; do # Loop thru folders until they differ
			in_single_dir="${check_in_dir[${i}]}"
			out_single_dir="${check_out_dir[${i}]}"
			if [ "${in_single_dir}" == "${out_single_dir}" 2>/dev/null ]; then
				common_dir="${common_dir}${in_single_dir}/"
			else # Paths no longer in common
				break
			fi
		done
	fi # if [ "${input_file}" == "${output_file}" 2>/dev/null ]
	
	# If space(s) in paths are in a common folder then space errors can be avoided
	input_file=$(echo "${input_file}" |sed "s@^${common_dir}@@g")
	output_file=$(echo "${output_file}" |sed "s@^${common_dir}@@g")
	check_name_space "${input_file}" "${output_file}" # Exit if space occurs beyond common path
	cd "${common_dir}" # Go to common directory to avoid spaces
elif [ "${#check_in_space[@]}" -gt '0' ]; then
	input_dir=$(dirname "${input_file}")
	input_file=$(basename "${input_file}")
	cd "${input_dir}" # Go to input directory to avoid spaces
elif [ "${#check_out_space[@]}" -gt '0' ]; then
	output_dir=$(dirname "${output_file}")
	output_file=$(basename "${output_file}")
	cd "${output_dir}" # Go to output directory to avoid spaces
fi # if [ "${#check_in_space[@]}" -gt '0' ] && [ "${#check_out_space[@]}" -gt '0' ]
#-----FSL throws errors if filepath has  whitespace: Trying work around [END]-----#

if [ -f "${output_file}" ]; then # Prompt to overwrite existing file
	until [ "${overwrite_file}" == 'yes' 2>/dev/null ]; do # User must agree to overwrite
		echo "${red}FILE ALREADY EXISTS: ${ora}${output_file}${whi}"
		echo "${ora}VIEW BET IMAGE: [${gre}v${ora}]${whi}"
		printf "${ora}OVERWRITE FILE? [${gre}y${ora}/${gre}n${ora}]:${whi}"
		read -r overwrite_option
		overwrite_option=$(echo "${overwrite_option}" |tr '[:upper:]' '[:lower:]') # upper to lowercase
		if [ "${overwrite_option}" == 'y' 2>/dev/null ] || [ "${overwrite_option}" == 'yes' 2>/dev/null ]; then
			overwrite_file='yes' # Overwrite files
		elif [ "${overwrite_option}" == 'n' 2>/dev/null ] || [ "${overwrite_option}" == 'no' 2>/dev/null ]; then
			echo "${red}NO BET OCCURRED${whi}" # Exit script without overwritting
			exit_message 0
		elif [ "${overwrite_option}" == 'v' 2>/dev/null ]; then # View previous brain extraction
			"${fsl_view_cmd}" "${output_file}" "${input_file}" "${output_file}" "${cm_option}" 2>/dev/null
			clear
		else # Invalid input
			invalid_msg "${overwrite_option}"
		fi
	done # until [ "${overwrite_file}" == 'yes' 2>/dev/null ]
fi # if [ -f "${output_file}" ]

if [ -z "${f_val}" ]; then
	f_val="${default_f}" # Use default if unspecified
fi

if [ -z "${g_val}" ]; then
	g_val="${default_g}" # Use default if unspecified
fi

bet_image

exit_message 0