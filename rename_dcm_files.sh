#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 11/07/2015 By: Evan Layher (layher@psych.ucsb.edu)
# Revised: 03/13/2016 By: Evan Layher (2.0): Updated code for efficiency
# Revised: 03/16/2016 By: Evan Layher (2.1): Include echo number in filename if > 1 (field maps)
# Revised: 02/16/2017 By: Evan Layher (2.2): Minor updates
#--------------------------------------------------------------------------------------#
# Rename and organize raw dicom files
#
# Requires the executable binary file 'dcmdump' from the DCMTK: http://dcmtk.org/dcmtk.php.en
# The file 'dcmdump' must be in the folder '/usr/bin': sudo mv dcmdump /usr/bin

## --- LICENSE INFORMATION --- ##
## rename_dcm_files.sh is the proprietary property of The Regents of the University of California ("The Regents.")

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
scan_dir=('SeriesNumber' 'SeriesDescription' 'StudyDate') # Input dicom headers ('SeriesNumber' begins all directories)
file_perm='664' # Dicom file permissions
dir_perm='775'  # Dicom directory permissions
default_delimiter='_' # Delimiter between dicom header information
dcm_ext='.dcm'        # Output dicom file extension

rename_alert='100'       # '100': Alert user of renaming progress every time this many files are renamed
check_file_count='1000'  # '1000': Input this many dicom files at a time to 'file' command
zero_pad_file='4'        # '4': Add leading zeros: Filename (instance number) 
zero_pad_folder='3'      # '3': Add leading zeros: Folder (series number)
default_depth_search='1' # '1': Find files with a maximum depth of this many folders

# DICOM field values
instance_num='InstanceNumber' # dcmdump field for MRI instance number
echo_num='EchoNumbers'        # dcmdump field for MRI echo number (Need for fieldmap)
series_num='SeriesNumber'     # dcmdump field for MRI series number
dicom_grep='DICOM medical imaging data$' # Identify dicom files: file |grep "${dicom_grep}"

# Default command locations (if commands are not initialized)
dcmdump_default='/usr/bin/dcmdump'
file_default='/usr/bin/file'
#--------------------------- DEFAULT SETTINGS ------------------------------#
max_bg_jobs='5' # Maximum number of background processes (1-10)
text_editors=('kwrite' 'gedit' 'open -a /Applications/TextWrangler.app' 'open' 'nano' 'emacs') # text editor commands in order of preference

IFS_original="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (needed when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
script_usage () { # Script explanation: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: Organize and rename dicom files
${pur}[${whi}1${pur}] ${whi}Creates scan folder: '${gre}${scan_dir[0]}${default_delimiter}${scan_dir[1]}${default_delimiter}${scan_dir[2]}${whi}'
${pur}[${whi}2${pur}] ${whi}Renames files: '${gre}${scan_dir[0]}${default_delimiter}${scan_dir[1]}${default_delimiter}${scan_dir[2]}${default_delimiter}${instance_num}${dcm_ext}${whi}'
     
${ora}ADVICE${whi}: Create an alias inside your ${ora}${HOME}/.bashrc${whi} file
(e.g. ${gre}alias dcm='${script_path}'${whi})
     
${ora}USAGE${whi}: Specify input/output folder ${ora}AND${whi}/${ora}OR ${whi}input dicom files
 [${ora}1${whi}] ${gre}dcm ${ora}/inpath /outpath ${whi}# Rename dicoms in '${ora}/inpath${whi}' and output in '${ora}/outpath${whi}'
 [${ora}2${whi}] ${gre}dcm ${ora}/inpath ${whi}# Rename dicoms in '${ora}/inpath${whi}'
 [${ora}3${whi}] ${gre}dcm ${whi}# Rename dicoms in working directory
 [${ora}4${whi}] ${gre}dcm ${ora}dcm_file1.dcm ${whi}# Renames '${ora}dcm_file1.dcm${whi}' in working directory
     ${red}NOTE: ${whi}If there are file input(s) then a scan folder is ${red}NOT CREATED${whi}
                  
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-cs${whi}  Prevent screen from clearing before script processes
 ${pur}-d${whi}   Input delimiter. ${ora}default: '${gre}${default_delimiter}${ora}'${whi}
 [${ora}5${whi}] ${gre}dcm ${pur}-d ${ora}'-' ${whi}# Change output delimiter to '${gre}-${whi}'
 ${pur}-f${whi}   Rename files ${red}WITHOUT ${whi}creating scan folder
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-m${whi}   Change folder depth search from ${ora}default: ${gre}${default_depth_search}${whi}
 [${ora}6${whi}] ${gre}dcm ${pur}-m ${ora}2 ${whi}# Search folder depth of ${ora}2${whi}
 [${ora}7${whi}] ${gre}dcm ${pur}-m ${whi}# Search entire folder depth
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-nt${whi}  Prevent script process time from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-p${whi}   Prevent changing file permissions to ${ora}file: ${gre}${file_perm} ${ora}folder: ${gre}${dir_perm}${whi}
     
${ora}DEFAULT SETTINGS${whi}:
background jobs: ${gre}${max_bg_jobs}${whi}
delimiter      : '${gre}${default_delimiter}${whi}'
permissions    : ${ora}FILE: ${gre}${file_perm} ${ora}FOLDER: ${gre}${dir_perm}${whi}
text editors: 
${gre}${text_editors[@]}${whi}

${ora}REFERENCE${whi}: ${gre}http://dcmtk.org/dcmtk.php.en${whi}
 [${ora}1${whi}] To get '${gre}dcmdump${whi}' download executable binary files: 
 ${ora}MAC            : ${gre}ftp://dicom.offis.de/pub/dicom/offis/software/dcmtk/dcmtk360/bin/dcmtk-3.6.0-mac-i686-static.tar.bz2${whi}
 ${ora}LINUX (static) : ${gre}ftp://dicom.offis.de/pub/dicom/offis/software/dcmtk/dcmtk360/bin/dcmtk-3.6.0-linux-i686-static.tar.bz2${whi}
 ${ora}LINUX (dynamic): ${gre}ftp://dicom.offis.de/pub/dicom/offis/software/dcmtk/dcmtk360/bin/dcmtk-3.6.0-linux-i686-dynamic.tar.bz2${whi}
 [${ora}2${whi}] Move ${gre}dcmdump${whi} into ${ora}/usr/bin${whi}: ${pur}sudo mv ${gre}dcmdump ${ora}/usr/bin${whi}
     
${ora}VERSION: ${gre}${version_number}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nt -nm
} # script_usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
script_start_time=$(date +%s)   # Time in seconds
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version_number='2.2'            # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
ignore_update='no'    # 'no' : No progress updates       [INPUT: '-i']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
show_time='yes'       # 'yes': Display process time      [INPUT: '-nt']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate inputs
	if [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-d' 2>/dev/null ] || \
	   [ "${1}" == '-f' 2>/dev/null ] || [ "${1}" == '-h' 2>/dev/null ] || \
	   [ "${1}" == '-i' 2>/dev/null ] || [ "${1}" == '--help' 2>/dev/null ] || \
	   [ "${1}" == '-m' 2>/dev/null ] || [ "${1}" == '-nc' 2>/dev/null ] || \
	   [ "${1}" == '-nt' 2>/dev/null ] || [ "${1}" == '-nm' 2>/dev/null ] || \
	   [ "${1}" == '-o' 2>/dev/null ] || [ "${1}" == '--open' 2>/dev/null ] || \
	   [ "${1}" == '-p' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ "${d_in}" == 'yes' 2>/dev/null ]; then
		delim="${1}"
		d_change='yes' # Indicate delimiter changed
		d_in='no' # Reset value
	elif [ "${m_in}" == 'yes' 2>/dev/null ]; then
		if [ "${1}" -eq "${1}" 2>/dev/null ]; then
			depth_search="${1}"   # Level of directory depth
			search_all_files='no' # Limit depth of search
		fi
		m_in='no' # Reset value
	elif [ -d "${1}" ]; then # Input or output folder
		if [ -z "${input_dir}" ]; then    # Input folder
			input_dir=$(mac_readlink "${1}")
		elif [ -z "${output_dir}" ]; then # Output folder
			output_dir=$(mac_readlink "${1}")
		else # Extra folder
			bad_inputs+=("MAX_2_FOLDER_INPUT:${1}")
		fi
	elif [ -f "${1}" ]; then  # Input file
		file_only='yes'       # Do NOT create new folder
		user_file_input='yes' # Use input files (do not search input directory)
		input_files+=($(mac_readlink "${1}"))
	else # Invalid user input
		bad_inputs+=("${1}")
	fi
} # option_eval

activate_options () { # Activate input options
	d_in='no' # Read in new delimiter
	m_in='no' # Read in max file search depth
	
	if [ "${1}" == '-cs' ]; then
		clear_screen='no'      # Do NOT clear screen at start
	elif [ "${1}" == '-d' ]; then
		d_in='yes'             # Read in new delimiter
	elif [ "${1}" == '-f' ]; then
		file_only='yes'        # Rename file without adding directory
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'    # Display help message
	elif [ "${1}" == '-i' ]; then
		ignore_update='yes'    # Do NOT update user of renaming progress
	elif [ "${1}" == '-m' ]; then
		m_in='yes'             # Read in max file search depth
		search_all_files='yes' # Search entire depth unless integer input
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no'   # Do NOT display messages in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'      # Do NOT display exit message
	elif [ "${1}" == '-nt' ]; then
		show_time='no'         # Do NOT display script process time
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'      # Open this script
	elif [ "${1}" == '-p' ]; then
		change_perm='no'      # Change file and directory permissions to defaults
	else # if option is not defined here (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

change_file_perms () { # Change permission of files and directories	
	if ! [ "${change_perm}" == 'no' 2>/dev/null ]; then
		if [ -f "${1}" ]; then   # Change file permission
			chmod ${file_perm} "${1}"
		elif [ -d "${1}" ]; then # Change folder permission
			chmod ${dir_perm} "${1}"
		fi
	fi
} # change_file_perms

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

control_bg_jobs () { # Controls number of background processes
	if [ "${max_bg_jobs}" -eq '1' 2>/dev/null ]; then
		wait # Proceed after all background processes are finished
	else
		if [ "${max_bg_jobs}" -gt '1' 2>/dev/null ] && [ "${max_bg_jobs}" -le '10' 2>/dev/null ]; then 
			true # Make sure variable is defined and valid number
		elif [ "${max_bg_jobs}" -gt '10' 2>/dev/null ]; then
			echo "RESTRICTING BACKGROUND PROCESSES TO 10"
			max_bg_jobs='10' # Background jobs should not exceed '10' (Lowers risk of crashing)
		else # If 'max_bg_jobs' not defined as integer
			echo "INVALID VALUE: max_bg_jobs='${max_bg_jobs}'"
			max_bg_jobs='1'
		fi
	
		job_count=($(jobs -p)) # Place job IDs into array
		if ! [ "$?" -eq '0' ]; then
			echo "JOB COUNT FAIL (control_bg_jobs): RESTRICTING BACKGROUND PROCESSES"
			max_bg_jobs='1'
			wait
		else
			if [ "${#job_count[@]}" -ge "${max_bg_jobs}" ]; then
				sleep 0.2
				control_bg_jobs
			fi
		fi # if ! [ "$?" -eq '0' ]
	fi # if [ "${max_bg_jobs}" -eq '1' 2>/dev/null ]
} # control_bg_jobs

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
			exit_message 99 -nh -nm -nt
		fi
	else
		echo "${red}MISSING FILE: ${ora}${file_to_open}${whi}"
	fi
} # open_text_editor

rename_dicom () { # Create dicom file structure and rename files
	# Get dicom header information of interest (gets all header information after first '[' and removes leading space)
	dcm_fields=($("${dcmdump_command}" "${1}" |grep -E -m "${#scan_dir[@]}" $(printf "%s|" ${scan_dir[@]} |sed 's/|$//g') |awk -F '[' '{$1 = ""; print $0}' |sed 's/^ //g'))
	# Get dicom instance number (number value only)
	ins_num=($("${dcmdump_command}" "${1}" |grep -m 1 "${instance_num}" |awk -F '[' '{print $2}' |awk -F ']' '{$NF=""; print $0}' |grep -o '[0-9]*'))
	# Get dicom echo number (number value only)
	check_echo=($("${dcmdump_command}" "${1}" |grep -m 1 "${echo_num}" |awk -F '[' '{print $2}' |awk -F ']' '{$NF=""; print $0}' |grep -o '[0-9]*'))

	if [ "${#dcm_fields[@]}" -ne "${#scan_dir[@]}" ]; then # Must find all dicom fields of interest
		echo "${red}FOUND ${gre}${#dcm_fields[@]}${ora}/${gre}${#scan_dir[@]} ${red}DICOM HEADERS. CHECK '${ora}scan_dir${red}' ARRAY"
		break # Error with dicom field(s)
	elif [ -z "${ins_num}" ]; then # Must have instance number
		echo "${red}MISSING ${ora}${instance_num}${red} FIELD${whi}"
	else
		if [ "${check_echo[0]}" -gt '1' 2>/dev/null ]; then
			filename=$(printf "%0${zero_pad_file}d" "${ins_num[0]}")"${delim}${check_echo[0]}${dcm_ext}"
		else # Do not include echo number in filename
			filename=$(printf "%0${zero_pad_file}d" "${ins_num[0]}")"${dcm_ext}"
		fi
		
		scan_name=() # Reset array
		for i_field in ${!scan_dir[@]}; do
			field_check="${scan_dir[${i_field}]}" 
			field_value=$(printf "%s${IFS}" "${dcm_fields[@]}" |grep "${field_check}" |awk -F ']' '{$NF=""; print $0}' |sed 's/ //g') # print all but last field (remove spaces)
			if [ "${field_check}" == "${series_num}" ]; then
				scan_number=$(printf "%0${zero_pad_folder}d" $(echo "${field_value}" |grep -o '[0-9]*')) # Integers only
			else
				scan_name+=("${field_value}")
			fi
		done
		
		base_outdir="${scan_number}${delim}"$(printf "%s${delim}" ${scan_name[@]} |sed "s/${delim}$//g")

		if [ "${file_only}" == 'yes' 2>/dev/null ]; then
			final_outdir="${output_dir}"
		else # Create new folder
			final_outdir="${output_dir}/${base_outdir}"
			if ! [ -d "${final_outdir}" ]; then
				mkdir -p "${final_outdir}" 2>/dev/null
			fi
		fi
		
		outfile="${final_outdir}/${base_outdir}_${filename}"
		if [ -f "${outfile}" ]; then
			echo "${red}FILE ALREADY EXISTS: ${ora}${outfile}${whi}"
		else
			mv "${1}" "${outfile}"
			vital_command "${LINENO}"
			change_file_perms "${final_file}"
			echo "${gre}CREATED: ${ora}${outfile}${whi}"
		fi
	fi
} # rename_dicom

vital_command () { # exits script if an essential command fails
	command_status="$?"
	command_line_number="${1}" # Must input as: vital_command ${LINENO}
	
	if ! [ -z "${command_status}" ] && [ "${command_status}" -ne '0' ]; then
		echo "${red}INVALID COMMAND: LINE ${ora}${command_line_number}${whi}"
		exit_message 98 -nh -nm -nt
	fi
} # vital_command

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
		elif [ "${exit_inputs}" == '-nt' 2>/dev/null ]; then
			show_time='no'
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
	
	# Display script process time
	if [ "${show_time}" == 'yes' 2>/dev/null ]; then # Script time message
		script_time_func 2>/dev/null
	fi
	
	printf "${formatreset}\n"
	IFS="${IFS_original}" # Reset IFS
	exit "${exit_type}"
} # exit_message

control_c () { # Crash message
	echo "${red}WAITING FOR BACKGROUND PROCESSES TO FINISH BEFORE CRASHING${whi}"
	wait # Waits for background processes to finish before crashing
	exit 96
} # control_c	

re_enter_input_message () { # Displays invalid input message
	clear
	echo "${red}INVALID INPUT:${whi}"
	printf "${ora}%s${IFS}${whi}" ${@}
	echo "${pur}PLEASE RE-ENTER INPUT${whi}"
} # re_enter_input_message

script_time_func () { # Script process time calculation
	func_end_time=$(date +%s) # Time in seconds
	user_input_time="${1}"
	valid_display_time='yes'
	
	if ! [ -z "${user_input_time}" ] && [ "${user_input_time}" -eq "${user_input_time}" 2>/dev/null ]; then
		func_start_time="${user_input_time}"
	elif ! [ -z "${script_start_time}" ] && [ "${script_start_time}" -eq "${script_start_time}" 2>/dev/null ]; then
		func_start_time="${script_start_time}"
	else # If no integer input or 'script_start_time' undefined
		valid_display_time='no'
	fi
	
	if [ "${valid_display_time}" == 'yes' ]; then
		script_process_time=$((${func_end_time} - ${func_start_time}))
		days=$((${script_process_time} / 86400))
		hours=$((${script_process_time} % 86400 / 3600))
		mins=$((${script_process_time} % 3600 / 60))
		secs=$((${script_process_time} % 60))
	
		if [ "${days}" -gt '0' ]; then 
			echo "PROCESS TIME: ${days} day(s) ${hours} hour(s) ${mins} minute(s) ${secs} second(s)"
		elif [ "${hours}" -gt '0' ]; then
			echo "PROCESS TIME: ${hours} hour(s) ${mins} minute(s) ${secs} second(s)"
		elif [ "${mins}" -gt '0' ]; then
			echo "PROCESS TIME: ${mins} minute(s) ${secs} second(s)"
		else
			echo "PROCESS TIME: ${secs} second(s)"
		fi
	else # Unknown start time
		echo "UNKNOWN PROCESS TIME"
	fi # if [ "${valid_display_time}" == 'yes' ]
} # script_time_func

#---------------------------------- CODE -----------------------------------#
trap control_c SIGINT 2>/dev/null # Capture crash input 'control + c'
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

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
	exit_message 0 -nm -nt
fi

# Exit script if invalid inputs found
if [ "${#bad_inputs[@]}" -gt '0' ]; then
	re_enter_input_message ${bad_inputs[@]}
	exit_message 1 -nt
fi

dcmdump_command=$(which dcmdump) # Determine 'dcmdump' location
if [ -z "${dcmdump_command}" ]; then
	if ! [ -z "${dcmdump_default}" ] && [ -f "${dcmdump_default}" ]; then
		dcmdump_command="${dcmdump_default}" # Use default file location
	else
		echo "${red}MISSING COMMAND: ${ora}dcmdump${whi}"
		echo "${ora}USE ${pur}-h${ora} OPTION FOR ${gre}DICOM Toolkit${ora} DOWNLOAD INSTRUCTIONS${whi}"
		exit_message 2 -nt
	fi
fi

file_command=$(which file) # Determine 'file' location
if [ -z "${file_command}" ]; then
	if ! [ -z "${file_default}" ] && [ -f "${file_default}" ]; then
		file_command="${file_default}" # Use default file location
	else
		echo "${red}MISSING COMMAND: ${ora}file${whi}"
		exit_message 3 -nt
	fi
fi

if [ -z "${input_dir}" ]; then
	input_dir=$(pwd)
fi

if [ -z "${output_dir}" ]; then
	output_dir="${input_dir}"
fi

if [ -z "${depth_search}" ]; then
	depth_search="${default_depth_search}"
fi

if ! [ "${user_file_input}" == 'yes' 2>/dev/null ]; then
	echo "${ora}SEARCHING FOR DICOM FILES: ${gre}${input_dir}${whi}"
	if [ "${search_all_files}" == 'yes' 2>/dev/null ]; then
		input_files=($(find "${input_dir}" -type f))
	else # Limit depth of search
		input_files=($(find "${input_dir}" -maxdepth "${depth_search}" -type f))
	fi
fi

echo "${ora}FINDING DICOM FILES FROM ${gre}${#input_files[@]} ${ora}INPUT FILES${whi}"
start_index='0'
until [ "${start_index}" -ge "${#input_files[@]}" ]; do # limit inputs to 'file'
	dcm_input+=($("${file_command}" $(printf "${input_files[*]:${start_index}:${check_file_count}}") |grep "${dicom_grep}" |awk -F ':' '{$NF=""; print $0}' |sed 's/ $//g'))
	start_index=$((${start_index} + ${check_file_count}))
done

if [ "${#dcm_input[@]}" -eq '0' ]; then
	echo "${red}NO DICOM FILES FOUND${whi}"
	exit_message 4
else
	echo "${gre}FOUND ${ora}${#dcm_input[@]} ${gre}DICOM FILES${whi}"
	if ! [ "${d_change}" == 'yes' ]; then
		delim="${default_delimiter}"
	fi
fi

check_series_number=($(printf "%s${IFS}" "${scan_dir[@]}" |grep "^${series_num}$"))

if [ "${#check_series_number[@]}" -eq '0' ]; then
	scan_dir=($(printf "%s${IFS}" "${series_num}" ${scan_dir[@]}))
fi # Must include series number

echo "${ora}RENAMING DICOM FILES: ${gre}${output_dir}${whi}"
count_thresh="${rename_alert}"
for i in ${!dcm_input[@]}; do
	rename_dicom "${dcm_input[${i}]}" &
	control_bg_jobs
	
	if ! [ "${ignore_update}" == 'yes' 2>/dev/null ] && [ "${i}" -eq "${count_thresh}" ]; then
		echo "${whi}----------${whi}"
		echo "${pur}${count_thresh}${ora}/${pur}${#dcm_input[@]} ${ora}FILES RENAMED${whi}"
		echo "${whi}----------${whi}"
		count_thresh=$((${count_thresh} + ${rename_alert}))
	fi # Alert user of renaming progress
done

exit_message 0