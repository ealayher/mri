#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 09/22/2014 By: Evan Layher (evan.layher@psych.ucsb.edu)
# Revised: 11/11/2015 By: Evan Layher (3.0) mac and linux compatible
# Revised: 04/12/2016 By: Evan Layher (3.1) allow paths with spaces (minor updates)
# Revised: 02/16/2017 By: Evan Layher (3.2) gzip nifti files and minor updates
# Revised: 08/18/2017 By: Evan Layher (3.3) compatible with fsleyes (FSL 5.0.10+)
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

default_bet_name='_bet' # If output unspecified add this to input filename
nifti_exts=('.nii' '.nii.gz') # Input file must have nifti extension
zip_ext='.nii.gz' # '.nii.gz' gzip files that lack this extension
#--------------------------- DEFAULT SETTINGS ------------------------------#
text_editors=('kwrite' 'gedit' 'open -a /Applications/TextWrangler.app' 'open' 'nano' 'emacs') # text editor commands in order of preference

IFS_original="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (needed when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
script_usage () { # Script explanation: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: Brain extract and view images with FSL's '${gre}bet${whi}' function
     
${ora}USAGE${whi}: Specify input and output (${ora}optional${whi}) nifti files
 [${ora}1${whi}] ${gre}input.nii.gz output.nii.gz${whi}
 [${ora}2${whi}] ${gre}input.nii.gz${whi} # outputs input${default_bet_name}${zip_ext}
     
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-cs${whi}  Prevent screen from clearing before script processes
 ${pur}-f${whi}   Input f value
 [${ora}3${whi}] ${gre}input.nii.gz output.nii.gz ${pur}-f ${ora}0.5${whi}
 ${pur}-g${whi}   Input g value
 [${ora}4${whi}] ${gre}input.nii.gz output.nii.gz ${pur}-g ${ora}0${whi}
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
     
${ora}DEFAULT SETTINGS${whi}:
f value     : ${gre}${default_f}${whi}
g value     : ${gre}${default_g}${whi}
text editors: 
${gre}${text_editors[@]}${whi}
 
${ora}REFERENCE: ${gre}http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/BET${whi}
 
${ora}VERSION: ${gre}${version_number}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm
} # script_usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version_number='3.3'            # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')

read_input_file='yes' # 'yes': Must input nifti file
read_output_file='no' # 'no' : Must input one output file
#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate inputs
	if [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-f' 2>/dev/null ] || \
	   [ "${1}" == '-g' 2>/dev/null ] || [ "${1}" == '-h' 2>/dev/null ] || \
	   [ "${1}" == '--help' 2>/dev/null ] || [ "${1}" == '-nc' 2>/dev/null ] || \
	   [ "${1}" == '-nm' 2>/dev/null ] || [ "${1}" == '-o' 2>/dev/null ] || \
	   [ "${1}" == '--open' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ "${f_in}" == 'yes' 2>/dev/null ]; then
		check_f=$(echo "${1}" |awk '{print ($1 >= 0 && $1 <= 1)}') # (Range 0 to 1)
		if [ "${check_f}" -eq '1' 2>/dev/null ]; then
			default_f="${1}"
		else
			bad_inputs+=("-f:${1}")
		fi
		
		f_in='no'
	elif [ "${g_in}" == 'yes' 2>/dev/null ]; then
		check_g=$(echo "${1}" |awk '{print ($1 >= -1 && $1 <= 1)}') # (Range -1 to 1)
		if [ "${check_g}" -eq '1' 2>/dev/null ]; then
			default_g="${1}"
		else
			bad_inputs+=("-g:${1}")
		fi
		
		g_in='no'
	elif [ -f "${1}" ] && [ "${read_input_file}" == 'yes' 2>/dev/null ]; then
		proceed='no'
		for i in ${!nifti_exts[@]}; do
			nifti_ext="${nifti_exts[${i}]}"
			check_nii=($(echo "${1}" |grep "${nifti_ext}$")) # Must be nifti file
			if [ "${#check_nii[@]}" -gt '0' ]; then
				input_file=$(mac_readlink "${1}") # similar to 'readlink -f' in linux
				input_filename=$(echo "${input_file}" |sed "s/${nifti_ext}$/${zip_ext}/g")
				gzip "${input_file}" 2>/dev/null # gzip nifti file
				
				if ! [ -f "${input_filename}" ]; then
					bad_inputs+=("FILE_NOT_ZIPPED:${input_file}")
				else
					input_file="${input_filename}"
				fi
				
				proceed='yes'
				break
			fi
		done # for i in ${!nifti_exts[@]}
		
		if [ "${proceed}" == 'no' 2>/dev/null ]; then
			bad_inputs+=("invalid_input_file:${1}")
		fi
		
		read_input_file='no'   # Only read in one input file
		read_output_file='yes' # Read output file
	elif [ "${read_output_file}" == 'yes' 2>/dev/null ]; then
		temp_outfile="${1}"
		for i in ${!nifti_exts[@]}; do
			nifti_ext="${nifti_exts[${i}]}"
			check_nii=($(echo "${1}" |grep "${nifti_ext}$")) # Check nifti extension
			
			if [ "${#check_nii[@]}" -gt '0' ]; then
				temp_outfile=$(echo "${temp_outfile}" |sed "s/${nifti_ext}$//g")
				break
			fi # Remove extension
		done # for i in ${!nifti_exts[@]}
		
		output_file=$(mac_readlink "${temp_outfile}${zip_ext}") # End file with zipped extension
		read_output_file='no' # Only read in one output file
	else
		bad_inputs+=("${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	f_in='no'
	g_in='no'
	
	if [ "${1}" == '-cs' ]; then
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
	else # if option is not defined here (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

bet_image () { # bet structural images
	clear
	echo "${gre}CREATING: ${ora}${output_file}${whi}"
	echo "${ora}F value: ${gre}${default_f}${whi}"
	echo "${ora}G value: ${gre}${default_g}${whi}"
	"${FSLDIR}/bin/fslreorient2std" "${input_file}" "${input_file}" & # Reorient brain to standard
	wait # Prevent corrupting nifti file
	"${FSLDIR}/bin/bet" "${input_file}" "${output_file}" -g "${default_g}" -f "${default_f}" & # Brain extraction
	wait # Prevent corrupting nifti file
	"${fsl_view_cmd}" "${output_file}" "${input_file}" "${output_file}" "${cm_option}" 2>/dev/null
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

mac_readlink () { # Get absolute path of a file
	dir_mac=$(dirname "${1}")   # Directory path
	file_mac=$(basename "${1}") # Filename
	wd_mac="$(pwd)" # Working directory path

	if [ -d "${dir_mac}" ]; then
		cd "${dir_mac}"
		echo "$(pwd)/${file_mac}" # Print full path
		cd "${wd_mac}" # Change directory back to original directory
	else
		echo "${1}" # Print input
	fi
} # mac_readlink

open_text_editor () { # Opens input file
	file_to_open="${1}"
	valid_text_editor='no'
	
	if [ -f "${file_to_open}" ]; then
		for i in ${!text_editors[@]}; do # Loop through indices
			${text_editors[i]} "${file_to_open}" 2>/dev/null &
			pid="$!" # Background process ID
			check_text_pid=($(ps "${pid}" |grep "${pid}")) # Check if pid is running
			
			if [ "${#check_text_pid[@]}" -gt '0' ]; then
				valid_text_editor='yes'
				break
			fi
		done

		if [ "${valid_text_editor}" == 'no' 2>/dev/null ]; then
			echo "${red}NO VALID TEXT EDITORS:${whi}"
			printf "${ora}%s${IFS}${whi}" ${text_editors[@]}
			exit_message 98 -nh -nm
		fi
	else
		echo "${red}MISSING FILE: ${ora}${file_to_open}${whi}"
	fi
} # open_text_editor

redo_bet () { # Redo bet with new parameters
	clear
	echo "${gre}CREATED: ${ora}${output_file}${whi}"
	echo "${ora}[${gre}a${ora}] ACCEPT BET IMAGE${whi}"
	echo "${ora}[${gre}r${ora}] REDO BET WITH DIFFERENT PARAMETERS${whi}"
	printf "${ora}[${gre}v${ora}] VIEW BET IMAGE:${whi}"
	read -r bet_option
	bet_option=$(echo "${bet_option}" |tr '[:upper:]' '[:lower:]') # upper to lowercase
	if [ "${bet_option}" == 'a' 2>/dev/null ]; then
		exit_message 0
	elif [ "${bet_option}" == 'r' 2>/dev/null ]; then
		set_new_parameters
		bet_image
	elif [ "${bet_option}" == 'v' 2>/dev/null ]; then # Load output file twice to manually save in correct directory
		"${fsl_view_cmd}" "${output_file}" "${input_file}" "${output_file}" "${cm_option}" 2>/dev/null
		redo_bet
	else
		re_enter_input_message "${bet_option}"
		redo_bet
	fi
} # redo_bet

set_new_parameters () { # input new f and g values
	valid_f_value='no'
	valid_g_value='no'
	
	clear
	until [ "${valid_f_value}" == 'yes' 2>/dev/null ]; do
		echo "${red}SMALLER ${gre}f${ora} values produce ${red}LARGER${ora} brain outputs${whi}"
		echo "${ora}PREVIOUS F VALUE: ${gre}${default_f}${whi}"
		printf "${ora}INPUT NEW F VALUE (${gre}0 ${ora}to ${gre}1${ora}):${whi}"
		read -r new_f
		check_f=$(echo "${new_f}" |awk '{print ($1 >= 0 && $1 <= 1)}') # (Range 0 to 1)
		if [ "${check_f}" -eq '1' 2>/dev/null ]; then
			default_f="${new_f}"
			valid_f_value='yes'
		else
			re_enter_input_message "${new_f}"
		fi
	done

	clear
	until [ "${valid_g_value}" == 'yes' 2>/dev/null ]; do
		echo "${red}POSITIVE ${gre}g${ora} values produce ${red}LARGER${ora} brain outputs on ${red}BOTTOM${ora}, ${red}SMALLER${ora} on ${red}TOP${whi}"
		echo "${ora}PREVIOUS G VALUE: ${gre}${default_g}${whi}"
		printf "${ora}INPUT NEW G VALUE (${gre}-1 ${ora}to ${gre}1${ora}):${whi}"
		read -r new_g
		check_g=$(echo "${new_g}" |awk '{print ($1 >= -1 && $1 <= 1)}') # (Range 0 to 1)
		
		if [ "${check_g}" -eq '1' 2>/dev/null ]; then
			default_g="${new_g}"
			valid_g_value='yes'
		else
			re_enter_input_message "${new_g}"
		fi
	done
} # set_new_parameters

vital_file () { # exits script if an essential file is missing
	for vitals; do
		if ! [ -e "${vitals}" 2>/dev/null ]; then
			bad_files+=("${vitals}")
		fi
	done
	
	if [ "${#bad_files[@]}" -gt '0' ]; then
		echo "${red}MISSING ESSENTIAL FILE(S):${whi}"
		printf "${pur}%s${IFS}${whi}" ${bad_files[@]}
		exit_message 97 -nh -nm
	fi
} # vital_file

#-------------------------------- MESSAGES ---------------------------------#
exit_message () { # Message before exiting script
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
	
	wait # Waits for background processes to finish before exiting

	# Suggest help message
	if [ "${suggest_help}" == 'yes' 2>/dev/null ]; then
		echo "${ora}TO DISPLAY HELP MESSAGE TYPE: ${gre}${script_path} -h${whi}"
	fi
	
	# Display exit message
	if ! [ "${display_exit}" == 'no' 2>/dev/null ]; then # Exit message
		echo "${pur}EXITING SCRIPT:${ora} ${script_path}${whi}"
	fi
	
	printf "${formatreset}\n"
	IFS="${IFS_original}" # Reset IFS
	exit "${exit_type}"
} # exit_message

control_c () { # Wait for background processes to finish
	all_jobs=($(jobs -p))
	if [ "${#all_jobs[@]}" -gt '0' ]; then
		echo "${red}FINISHING BET PROCESSING BEFORE CRASHING TO PREVENT CORRUPTING FILES${whi}"
		wait
	fi
	
	cd "${wd}" # Change back to working directory
	IFS="${IFS_original}" # Reset IFS
	printf '\n' # print new line
	exit_message 0
} # control_c

re_enter_input_message () { # Displays invalid input message
	clear
	echo "${red}INVALID INPUT:${whi}"
	printf "${ora}%s${IFS}${whi}" ${@}
	echo "${pur}PLEASE RE-ENTER INPUT${whi}"
} # re_enter_input_message

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
fi

base_script=$(basename "${script_path}")
echo "RUNNING: ${gre}${base_script}"
for inputs; do # Reads through all inputs
	option_eval "${inputs}"
done

if ! [ "${clear_screen}" == 'no' 2>/dev/null ]; then
	clear     # Clears screen unless activation of input option: '-cs'
fi

color_formats # Activates or inhibits colorful output

# Display help message or open file
if [ "${activate_help}" == 'yes' 2>/dev/null ]; then # '-h' or '--help'
	script_usage
elif [ "${open_script}" == 'yes' 2>/dev/null ]; then # '-o' or '--open'
	open_text_editor "${script_path}" ${text_editors[@]}
	exit_message 0 -nm
fi

# Exit script if invalid inputs found
if [ "${#bad_inputs[@]}" -gt '0' ]; then
	re_enter_input_message ${bad_inputs[@]}
	exit_message 2
elif [ -z "${input_file}" ]; then  # Input file must be specified
	echo "${red}MUST SPECIFY NIFTI INPUT FILE${whi}"
	exit_message 3
elif [ -z "${output_file}" ]; then # If output file is unspecified give default name
	output_file=$(echo "${input_file}" |sed "s/${zip_ext}$//g")"${default_bet_name}${zip_ext}"
fi # if [ "${#bad_inputs[@]}" -gt '0' ]

check_name_space $(basename "${input_file}") $(basename "${output_file}")

check_in_space=($(echo "${input_file}" |grep ' '))
check_out_space=($(echo "${output_file}" |grep ' '))

wd="$(pwd)" # Change directories if path(s) contain spaces
if [ "${#check_in_space[@]}" -gt '0' ] && [ "${#check_out_space[@]}" -gt '0' ]; then
	if [ "${input_file}" == "${output_file}" 2>/dev/null ]; then
		common_dir=$(dirname "${input_file}") # If files are the same
	else
		check_in_dir=($(echo "${input_file}" |sed "s@/@\\${IFS}@g"))
		check_out_dir=($(echo "${output_file}" |sed "s@/@\\${IFS}@g"))
		common_dir='/' # Directory that is common to both files
		for i in ${!check_in_dir[@]}; do
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

if [ -f "${output_file}" ]; then # Prompt to overwrite existing file
	until [ "${overwrite_file}" == 'yes' 2>/dev/null ]; do
		echo "${red}FILE ALREADY EXISTS: ${ora}${output_file}${whi}"
		echo "${ora}VIEW BET IMAGE: [${gre}v${ora}]${whi}"
		printf "${ora}OVERWRITE FILE? [${gre}y${ora}/${gre}n${ora}]:${whi}"
		read -r overwrite_option
		overwrite_option=$(echo "${overwrite_option}" |tr '[:upper:]' '[:lower:]') # upper to lowercase
		if [ "${overwrite_option}" == 'y' 2>/dev/null ] || [ "${overwrite_option}" == 'yes' 2>/dev/null ]; then
			overwrite_file='yes'
		elif [ "${overwrite_option}" == 'n' 2>/dev/null ] || [ "${overwrite_option}" == 'no' 2>/dev/null ]; then
			echo "${red}NO BET OCCURRED${whi}"
			exit_message 0
		elif [ "${overwrite_option}" == 'v' 2>/dev/null ]; then
			"${fsl_view_cmd}" "${output_file}" "${input_file}" "${output_file}" "${cm_option}" 2>/dev/null
			clear
		else
			re_enter_input_message "${overwrite_option}"
		fi
	done
fi

bet_image

exit_message 0