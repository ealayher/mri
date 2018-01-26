#!/bin/bash
#--------------------------------------------------------------------------------------#
# Created: 11/07/2015 By: Evan Layher (1.0): (layher@psych.ucsb.edu)
# Revised: 03/13/2016 By: Evan Layher (2.0): Updated code for efficiency
# Revised: 03/16/2016 By: Evan Layher (2.1): Include echo number in filename if > 1 (field maps)
# Revised: 02/16/2017 By: Evan Layher (2.2): Alert user of progress + minor updates
# Revised: 06/28/2017 By: Evan Layher (2.3): Update download instructions
# Revised: 01/19/2018 By: Evan Layher (2.4): Specify all parameters from commandline + minor updates
# Revised: 01/25/2018 By: Evan Layher (2.5): Ignore 'EchoNumbers' header if missing
#--------------------------------------------------------------------------------------#
# Rename and organize raw dicom files

# Requires the executable binary file 'dcmdump' from the DCMTK: http://dcmtk.org/dcmtk.php.en

## --- LICENSE INFORMATION --- ##
## rename_dcm_files.sh is the proprietary property of The Regents of the University of California ("The Regents.")

## Copyright © 2014-18 The Regents of the University of California, Davis campus. All Rights Reserved.

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
def_dcm_hdrs=('SeriesNumber' 'SeriesDescription' 'StudyDate') # Default dicom headers ('SeriesNumber' begins all output folders)
def_file_perm='664' # '664' : Default dicom file permissions
def_dir_perm='775'  # '775' : Default dicom permissions
def_delim='_'       # '_'   : Default delimiter between dicom header information
dcm_ext='.dcm'      # '.dcm': Output dicom file extension
	
# Dicom headers associated with individual files
file_dcm_hdrs=('AcquisitionDate' 'AcquisitionNumber' 'AcquisitionTime' 'ContentDate' 
	'ContentTime' 'EchoNumbers' 'InstanceNumber') # file_dcm_hdrs

# Dicom headers associated with files within a series/sequence (single scan)
series_dcm_hdrs=('EchoTime' 'ImagedNucleus' 'ImagingFrequency' 'NumberOfAverages' 
	'PixelBandwidth' 'ProtocolName' 'RepetitionTime' 'SequenceName' 'SeriesDate' 
	'SeriesDescription' 'SeriesNumber' 'SeriesTime') # series_dcm_hdrs

# Dicom headers associated with a scanning session
study_dcm_hdrs=('InstitutionName' 'MagneticFieldStrength' 'Manufacturer' 'PatientID' 
	'RequestingPhysician' 'StudyDate' 'StudyDescription' 'StudyTime') # study_dcm_hdrs

# All valid dicom headers
valid_dcm_hdrs=($(printf "%s${IFS}" ${file_dcm_hdrs[@]} ${series_dcm_hdrs[@]} ${study_dcm_hdrs[@]}))

rename_alert='100'    # '100': Alert user of renaming progress every time this many files are renamed
chk_file_count='1000' # '1000': Input this many dicom files at a time to 'file' command
def_z_pad_ins='4'     # '4': Default leading zeros: instance number
def_z_pad_ser='3'     # '3': Default leading zeros: series number
def_search_depth='1'  # '1': Find files with a maximum depth of this many folders

# Essential DICOM field values (used with dcmdump)
echo_num='EchoNumbers'        # MRI echo number (needed for scans with multiple echos, e.g. fieldmaps)
instance_num='InstanceNumber' # MRI instance number (within series)
series_num='SeriesNumber'     # MRI series number (within MRI session)
dcm_grep='DICOM medical imaging data$' # Identify dicom files: file |grep "${dcm_grep}"

# Default command locations (if commands are not initialized)
def_dcmdump='/usr/bin/dcmdump'
def_file='/usr/bin/file'

# Suppress keywords (Prevent terminal display)
sup_all='all'     # Suppress all terminal display
sup_alert='alert' # Suppress display of file progress
sup_files='files' # Suppress display of files created
sup_ver='verify'  # Suppress display of verification screen (default)
verify_time='10'  # (secs) Display settings before running (input -s to suppress)

dcmtoolkit_page='http://dcmtk.org/dcmtk.php.en' # Website to download DICOM Toolkit
#--------------------------- DEFAULT SETTINGS ------------------------------#
max_bg_jobs='5' # Maximum background processes (1-10)
text_editors=('kwrite' 'kate' 'gedit' 'open -a /Applications/BBEdit.app' 'open') # GUI text editor commands in preference order

IFS_old="${IFS}" # whitespace separator
IFS=$'\n' # newline separator (useful when paths have whitespace)
#------------------------- SCRIPT HELP MESSAGE -----------------------------#
usage () { # Help message: '-h' or '--help' option
	echo "${red}HELP MESSAGE: ${gre}${script_path}${whi}
${ora}DESCRIPTION${whi}: Organize and rename ${ora}DICOM ${whi}files
${red}REQUIRES ${gre}DICOM TOOLKIT ${red}PROGRAM${whi}: ${gre}${dcmtoolkit_page}${whi}
${pur}[${whi}1${pur}] ${whi}Creates output folders based on ${ora}DICOM ${whi}file header information
${pur}[${whi}2${pur}] ${whi}Renames ${ora}DICOM ${whi}files based on header information
     
${ora}ADVICE${whi}: Create alias in ${ora}${HOME}/.bashrc${whi}
(e.g. ${gre}alias dcm='${script_path}'${whi})
     
${ora}USAGE${whi}: Specify ${ora}DICOM ${whi}files to rename and header information
 [${ora}1${whi}] ${gre}dcm ${whi}# Searches working directory for files (${pur}default headers${whi})
 [${ora}2${whi}] ${gre}dcm ${ora}file1.dcm file2.dcm ${whi}# Rename input ${ora}DICOM(s)${whi} (${pur}default headers${whi})
 [${ora}3${whi}] ${gre}dcm ${ora}dcm_folder ${whi}# Rename ${ora}DICOM(s)${whi} within folder(s) (${pur}default headers${whi})
 [${ora}4${whi}] ${gre}dcm ${ora}dcm_folder ${pur}${series_num} SeriesDescription ${instance_num}${whi}
     # ${ora}FILENAME${whi}: ${gre}${series_num}${def_delim}SeriesDescription${def_delim}${instance_num}${dcm_ext}${whi}
     
${ora}LIST OF VALID DICOM HEADER INPUTS:${whi}
$(display_values ${valid_dcm_hdrs[@]})     
${ora}OPTIONS${whi}: Can input multiple options in any order
 ${pur}-cs${whi}  Prevent clearing screen at start
 ${pur}-del${whi} Delimiter between filename values (${pur}default${whi}: '${ora}${def_delim}${whi}')
 [${ora}5${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-del ${whi}'${ora}${def_delim}${whi}'
 ${pur}-f${whi}   Change filenames ${red}WITHOUT ${whi}creating new output folder
 ${pur}-h${whi} or ${pur}--help${whi}  Display this message
 ${pur}-m${whi}   Maximum subfolder search depth when input folder specified (${pur}default${whi}: ${ora}${def_search_depth}${whi})
 [${ora}6${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-m ${ora}${def_search_depth}${whi}
 ${pur}-nc${whi}  Prevent color printing in terminal
 ${pur}-nm${whi}  Prevent exit message from displaying
 ${pur}-nt${whi}  Prevent script process time from displaying
 ${pur}-o${whi} or ${pur}--open${whi} Open this script
 ${pur}-out${whi} Specify output folder (can include ${ora}DICOM ${whi}header information)
 [${ora}7${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-out ${ora}~/Desktop${whi} # Output to Desktop
 [${ora}8${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-out ${ora}~/Desktop ${pur}PatientID StudyDate${whi}
     # ${ora}FOLDERNAME${whi}: ${gre}~/Desktop/PatientID${def_delim}StudyDate${whi}
 [${ora}9${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-out my-study PatientID StudyDate${whi}
     # ${ora}FOLDERNAME${whi}: ${gre}$(pwd)/my-study${def_delim}PatientID${def_delim}StudyDate
 ${pur}-p${whi}  Prevent changing file/folder permission values
 ${pur}-pd${whi} Specify permission values of directories ${pur}(${whi}[${ora}0${whi}-${ora}7${whi}][${ora}0${whi}-${ora}7${whi}][${ora}0${whi}-${ora}7${whi}]${pur})${whi} (${pur}default${whi}: ${ora}${def_dir_perm}${whi})
 [${ora}10${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-pd ${ora}${def_dir_perm}${whi}
 ${pur}-pf${whi} Specify permission values of files ${pur}(${whi}[${ora}0${whi}-${ora}7${whi}][${ora}0${whi}-${ora}7${whi}][${ora}0${whi}-${ora}7${whi}]${pur})${whi} (${pur}default${whi}: ${ora}${def_file_perm}${whi})
 [${ora}11${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-pf ${ora}${def_file_perm}${whi}
 ${pur}-s${whi}  Suppress display messages
     ${ora}KEYWORDS: ${whi}Can input multiple keywords in any order
     ${ora}(${pur}1${ora}) ${sup_alert} ${whi}# Suppress alert messages
     ${ora}(${pur}2${ora}) ${sup_all} ${whi}# Suppress ${red}ALL ${whi}messages
     ${ora}(${pur}3${ora}) ${sup_files} ${whi}# Suppress rename file messages
     ${ora}(${pur}4${ora}) ${sup_ver} ${whi}# Suppress verification screen
 [${ora}12${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-s ${whi}(${pur}default${whi}: ${ora}suppress verification screen${whi})
 [${ora}13${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-s ${ora}${sup_files} ${sup_alert}${whi}
 ${pur}-zi${whi} Zero pad ${ora}${instance_num} ${whi}value (${pur}default${whi}: ${ora}${def_z_pad_ins}${whi})
 [${ora}14${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-zi ${ora}${def_z_pad_ins}${whi}
 ${pur}-zs${whi} Zero pad ${ora}${series_num} ${whi}value (${pur}default${whi}: ${ora}${def_z_pad_ser}${whi})
 [${ora}15${whi}] ${gre}dcm ${ora}dcm_folder ${pur}-zs ${ora}${def_z_pad_ser}${whi}
 
${ora}DOWNLOAD ${gre}DICOM TOOLKIT ${ora}INSTRUCTIONS: ${gre}${dcmtoolkit_page}${whi}
 ${pur}[${whi}1${pur}] ${whi}Download source code (e.g. ${gre}dcmtk-3.6.2.tar.gz${whi})
 ${pur}[${whi}2${pur}] ${whi}Go into main directory (e.g. ${ora}cd ${gre}dcmtk-3.6.2${whi})
 ${pur}[${whi}3${pur}] ${whi}Run the following commands in order:
     ${ora}(${pur}1${ora}) ${gre}./configure${whi}
     ${ora}(${pur}2${ora}) ${gre}make all${whi}
     ${ora}(${pur}3${ora}) ${gre}make install ${whi}(${ora}on linux use: ${gre}sudo make install${whi})
     ${ora}(${pur}4${ora}) ${gre}make distclean${whi}
 ${ora}Refer to ${gre}INSTALL ${ora}file for troubleshooting${whi}
 
${ora}VERSION: ${gre}${version}${whi}
${red}END OF HELP: ${gre}${script_path}${whi}"
	exit_message 0 -nm -nt
} # usage

#----------------------- GENERAL SCRIPT VARIABLES --------------------------#
start_time=$(date +%s) # Time in seconds
script_path="${BASH_SOURCE[0]}" # Script path (becomes absolute path later)
version='2.5' # Script version number

	###--- 'yes' or 'no' options (inputs do the opposite of default) ---###
activate_colors='yes' # 'yes': Display messages in color [INPUT: '-nc']
activate_help='no'    # 'no' : Display help message      [INPUT: '-h' or '--help']
change_perm='yes'     # 'yes': Change file permissions   [INPUT: '-p']
clear_screen='yes'    # 'yes': Clear screen at start     [INPUT: '-cs']
disp_alert='yes'      # 'yes': Display alert messages    [INPUT: '-s', ${sup_alert}/${sup_all}]
disp_files='yes'      # 'yes': Display filename changes  [INPUT: '-s', ${sup_files}/${sup_all}]
disp_ver='yes'        # 'yes': Display verification      [INPUT: '-s', ${sup_ver}/${sup_all}]
display_exit='yes'    # 'yes': Display an exit message   [INPUT: '-nm']
files_only='no'       # 'no' : Do not create directories [INPUT: '-f']
open_script='no'      # 'no' : Open this script          [INPUT: '-o' or '--open']
show_time='yes'       # 'yes': Display process time      [INPUT: '-nt']
suggest_help='no'     # 'no' : Suggest help (within script option: '-nh')

#-------------------------------- FUNCTIONS --------------------------------#
option_eval () { # Evaluate user inputs
	if [ "${1}" == '-cs' 2>/dev/null ] || [ "${1}" == '-del' 2>/dev/null ] || \
	   [ "${1}" == '-f' 2>/dev/null ] || [ "${1}" == '-h' 2>/dev/null ] || \
	   [ "${1}" == '--help' 2>/dev/null ] || [ "${1}" == '-m' 2>/dev/null ] || \
	   [ "${1}" == '-nc' 2>/dev/null ] || [ "${1}" == '-nm' 2>/dev/null ] || \
	   [ "${1}" == '-nt' 2>/dev/null ] || [ "${1}" == '-o' 2>/dev/null ] || \
	   [ "${1}" == '--open' 2>/dev/null ] || [ "${1}" == '-out' 2>/dev/null ] || \
	   [ "${1}" == '-p' 2>/dev/null ] || [ "${1}" == '-pd' 2>/dev/null ] || \
	   [ "${1}" == '-pf' 2>/dev/null ] || [ "${1}" == '-s' 2>/dev/null ] || \
	   [ "${1}" == '-zi' 2>/dev/null ] || [ "${1}" == '-zs' 2>/dev/null ]; then
		activate_options "${1}"
	elif [ "${1:0:1}" == '-' 2>/dev/null ]; then # Invalid input option
		bad_inputs+=("INVALID-OPTION:${1}")
	elif [ "${d_in}" == 'yes' 2>/dev/null ]; then # -del (delimiter)
		delim="${1}" # delimiter between file inputs
		d_in='no' # Reset value
	elif [ "${m_in}" == 'yes' 2>/dev/null ]; then # -m (maximum folder search depth)
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -gt '0' 2>/dev/null ]; then
			search_depth="${1}"
		else
			bad_inputs+=("SEARCH-DEPTH-MUST-BE-1-OR-GREATER_-m:${1}")
		fi
		
		m_in='no' # Reset value
	elif [ "${o_in}" == 'yes' 2>/dev/null ]; then # -out (output folder name)
		chk_path=$(echo "${1}" |grep '/') # Check for output folder path
		if ! [ -z "${chk_path}" ]; then # Output folder path
			outdir=$(mac_readlink "${1}") # Output folder path (only 1 folder accepted)
		else # Main folder output
			chk_dcm_hdr=($(printf "%s${IFS}" ${valid_dcm_hdrs[@]} |grep "^${1}$")) # Check if dicom value
			if [ "${#chk_dcm_hdr[@]}" -gt '0' ]; then # Check if general dicom header
				chk_dcm_hdr_study=($(printf "%s${IFS}" ${study_dcm_hdrs[@]} |grep "^${1}$")) # Must be study value
				if [ "${#chk_dcm_hdr_study[@]}" -eq '0' ]; then # Invalid 'study' dicom header
					bad_inputs+=("DCM-HEADER-CANNOT-BE-USED-FOR-FOLDER-NAME_-o:${1}")
				else # Include in output foldername
					outdir_names+=("${1}") # Collect all 'study' headers for output foldername
				fi
			else # non-dicom header output foldername
				outdir_names+=("${1}") # Collect all output foldernames
			fi # if [ "${#chk_dcm_hdr[@]}" -gt '0' ]
		fi # if ! [ -z "${chk_path}" ]
	elif [ "${pd_in}" == 'yes' 2>/dev/null ]; then # -pd (directory permissions)
		check_perm "${1}"
		dir_perm="${1}"
		pd_in='no' # Reset value
	elif [ "${pf_in}" == 'yes' 2>/dev/null ]; then # -pf (file permissions)
		check_perm "${1}"
		file_perm="${1}"
		pf_in='no' # Reset value
	elif [ "${s_in}" == 'yes' 2>/dev/null ]; then # -s (suppress display messages)
		s_in_count=$((${s_in_count} + 1))
		if [ "${1}" == "${sup_all}" 2>/dev/null ]; then # Suppress all messages
			disp_alert='no'
			disp_files='no'
			disp_ver='no'
		elif [ "${1}" == "${sup_alert}" 2>/dev/null ]; then # Suppress alerts
			disp_alert='no'
		elif [ "${1}" == "${sup_files}" 2>/dev/null ]; then # Suppress file verification
			disp_files='no'
		elif [ "${1}" == "${sup_ver}" 2>/dev/null ]; then # Suppress verification step
			disp_ver='no'
		else # Invalid suppress keyword (-s)
			bad_inputs+=("INVALID-KEYWORD_-s:${1}")
		fi
	elif [ "${zi_in}" == 'yes' 2>/dev/null ]; then
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -ge '0' 2>/dev/null ]; then
			z_pad_ins="${1}"
		else
			bad_inputs+=("MUST-INPUT-INTEGER_-zi:${1}")
		fi
		
		zi_in='no' # Reset value
	elif [ "${zs_in}" == 'yes' 2>/dev/null ]; then
		if [ "${1}" -eq "${1}" 2>/dev/null ] && [ "${1}" -ge '0' 2>/dev/null ]; then
			z_pad_ser="${1}"
		else
			bad_inputs+=("MUST-INPUT-INTEGER_-zs:${1}")
		fi
		
		zs_in='no' # Reset value
	elif [ -d "${1}" ]; then
		input_dirs+=($(mac_readlink "${1}")) # Get files from input folders
	elif [ -f "${1}" ]; then
		input_files+=($(mac_readlink "${1}"))
	else # Check for dicom header
		chk_head=($(printf "%s${IFS}" ${valid_dcm_hdrs[@]} |grep "^${1}$"))
		if [ "${#chk_head[@]}" -gt '0' ]; then
			dcm_hdrs+=("${1}")
		else # Invalid input
			bad_inputs+=("INVALID-DICOM-HEADER:${1}")
		fi
	fi
} # option_eval

activate_options () { # Activate input options
	# Reset option values
	d_in='no'  # Read in delimiter values
	m_in='no'  # Read in max search depth values
	o_in='no'  # Read in output folder
	pd_in='no' # Read in directory permission
	pf_in='no' # Read in file permission
	s_in='no'  # Read in suppress output values
	zi_in='no' # Read in instance number zero pad
	zs_in='no' # Read in series number zero pad
	
	if [ "${1}" == '-cs' ]; then
		clear_screen='no'    # Do NOT clear screen at start
	elif [ "${1}" == '-del' ]; then
		d_in='yes'           # Read in delimiter values
	elif [ "${1}" == '-f' ]; then
		files_only='yes'     # Do not create directories
	elif [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
		activate_help='yes'  # Display help message
	elif [ "${1}" == '-m' ]; then
		m_in='yes'           # Read in max search depth values
	elif [ "${1}" == '-nc' ]; then
		activate_colors='no' # Do NOT display messages in color
	elif [ "${1}" == '-nm' ]; then
		display_exit='no'    # Do NOT display exit message
	elif [ "${1}" == '-nt' ]; then
		show_time='no'       # Do NOT display script process time
	elif [ "${1}" == '-o' ] || [ "${1}" == '--open' ]; then
		open_script='yes'    # Open this script
	elif [ "${1}" == '-out' ]; then
		o_in='yes'           # Read in output folder
	elif [ "${1}" == '-p' ]; then
		change_perm='no'     # Do not change file permissions
	elif [ "${1}" == '-pd' ]; then
		pd_in='yes'          # Read in directory permission
	elif [ "${1}" == '-pf' ]; then
		pf_in='yes'          # Read in file permission
	elif [ "${1}" == '-s' ]; then
		s_in='yes'           # Read in suppress output values
		s_in_count='0'       # Count number of '-s' inputs (defaults to suppress verification)
	elif [ "${1}" == '-zi' ]; then
		zi_in='yes'          # Read in instance number zero pad
	elif [ "${1}" == '-zs' ]; then
		zs_in='yes'          # Read in series number zero pad
	else # if option is undefined (for debugging)
		bad_inputs+=("ERROR:activate_options:${1}")
	fi
} # activate_options

change_file_perms () { # Change permission of files and directories	
	if [ "${change_perm}" == 'yes' 2>/dev/null ]; then
		if [ -f "${1}" ]; then   # Change file permission
			chmod ${file_perm} "${1}"
		elif [ -d "${1}" ]; then # Change folder permission
			chmod ${dir_perm} "${1}"
		fi
	fi
} # change_file_perms

check_bad_inputs () { # Exit script if invalid inputs	
	if [ "${#bad_inputs[@]}" -gt '0' ]; then
		clear
		echo "${red}INVALID INPUT:${whi}"
		display_values ${bad_inputs[@]}
		exit_message 99 -nt
	fi
} # check_bad_inputs

check_perm () { # Check permission values
	in_perm="${1}"
	# Must input 3 integer permission values
	if [ "${#in_perm}" -eq '3' ] && [ "${in_perm:0:1}" -eq "${in_perm:0:1}" 2>/dev/null ] && \
	   [ "${in_perm:1:1}" -eq "${in_perm:1:1}" 2>/dev/null ] && [ "${in_perm:2:1}" -eq "${in_perm:2:1}" 2>/dev/null ]; then
		if [ "${in_perm:0:1}" -lt '0' ] || [ "${in_perm:0:1}" -gt '7' ] || \
		   [ "${in_perm:1:1}" -lt '0' ] || [ "${in_perm:1:1}" -gt '7' ] || \
		   [ "${in_perm:2:1}" -lt '0' ] || [ "${in_perm:2:1}" -gt '7' ]; then
			bad_inputs+=("EACH-VALUE-MUST-BE-INTEGER-FROM-0-8_-pd_-pf:${1}")
		fi
	else
		bad_inputs+=("MUST-INPUT-3-PERMISSION-INTEGERS_-pd_-pf:${1}")
	fi
} # check_perm

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
			echo "${red}RESTRICTING BACKGROUND PROCESSES TO 10${whi}"
			max_bg_jobs='10' # Background jobs should not exceed '10' (Lowers risk of crashing)
		else # If 'max_bg_jobs' not defined as integer
			echo "${red}INVALID VALUE: ${ora}max_bg_jobs='${gre}${max_bg_jobs}${ora}'${whi}"
			max_bg_jobs='1'
		fi
	
		job_count=($(jobs -p)) # Place job IDs into array
		if ! [ "$?" -eq '0' ]; then # If 'jobs -p' command fails
			echo "${red}ERROR (${ora}control_bg_jobs${red}): ${ora}RESTRICTING BACKGROUND PROCESSES${whi}"
			max_bg_jobs='1'
			wait
		else
			if [ "${#job_count[@]}" -ge "${max_bg_jobs}" ]; then
				sleep 0.2 # Wait 0.2 seconds to prevent overflow errors
				control_bg_jobs # Check job count
			fi
		fi # if ! [ "$?" -eq '0' ]
	fi # if [ "${max_bg_jobs}" -eq '1' 2>/dev/null ]
} # control_bg_jobs

display_values () { # Display output with numbers
	if [ "${#@}" -gt '0' ]; then
		val_count=($(seq 1 1 ${#@}))
		vals_and_count=($(paste -d "${IFS}" <(printf "%s${IFS}" ${val_count[@]}) <(printf "%s${IFS}" ${@})))
		printf "${pur}[${ora}%s${pur}] ${gre}%s${IFS}${whi}" ${vals_and_count[@]}
	fi
} # display_values

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
			exit_message 98 -nh -nm -nt
		fi
	else # Missing input file
		echo "${red}MISSING FILE: ${ora}${open_file}${whi}"
	fi # if [ -f "${open_file}" ]; then
} # open_text_editor

rename_dicom () { # Create dicom file structure and rename files
	in_dcm="${1}" # Input dicom file
	get_output_name="${2}" # If not empty simply display output filename
	
	# Get requested dicom header information (gets all header information after first '[' and removes leading space)
	dcm_fields=($("${cmd_dcmdump}" "${in_dcm}" |grep -E -m "${#dcm_hdrs[@]}" $(printf " %s$|" ${dcm_hdrs[@]} |sed 's/|$//g') |awk -F '[' '{$1 = ""; print $0}' |sed 's/^ //g'))
	vital_command "${LINENO}"

	# "${echo_num}" header not always present and is irrelevant if missing (do not throw error if missing)
	if [ "${#dcm_fields[@]}" -eq $((${#dcm_hdrs[@]} - 1)) ]; then
		chk_echos_field=($(printf "%s${IFS}" ${dcm_fields[@]} |grep " ${echo_num}$"))
		chk_echos_hdr=($(printf "%s${IFS}" ${dcm_hdrs[@]} |grep "^${echo_num}$"))

		if [ "${#chk_echos_field[@]}" -eq '0' ] && [ "${#chk_echos_hdr[@]}" -gt '0' ]; then
			dcm_hdrs_input=($(printf "%s${IFS}" ${dcm_hdrs[@]} |grep -v "^${echo_num}$")) # Exclude "${echo_num}"
		fi
	fi # if [ "${#dcm_fields[@]}" -eq $((${#dcm_hdrs[@]} - 1)) ]
	
	if [ "${#dcm_hdrs_input[@]}" -eq '0' ]; then
		dcm_hdrs_input=($(printf "%s${IFS}" ${dcm_hdrs[@]})) # Temporary headers array
	fi

	if [ "${#dcm_fields[@]}" -ne "${#dcm_hdrs_input[@]}" ]; then # Must find all dicom fields of interest
		echo "${red}ERROR: ${ora}ONLY FOUND ${gre}${#dcm_fields[@]}${ora}/${gre}${#dcm_hdrs_input[@]} ${ora}DICOM HEADERS${whi}: ${gre}${in_dcm}${whi}"
		break # Error with dicom field(s)
	else # Prepare new dicom filename
		scan_name=() # Reset array (new dicom file output name)
		sub_name=()  # Reset array (subfolder output name)
		for j_dcm in ${!dcm_hdrs_input[@]}; do
			field_chk="${dcm_hdrs_input[${j_dcm}]}"
			file_chk=($(printf "%s${IFS}" ${file_dcm_hdrs[@]} |grep "^${field_chk}$")) # Exclude from subfolder name
			field_value=$(printf "%s${IFS}" "${dcm_fields[@]}" |grep " ${field_chk}$" |awk -F ']' '{$NF=""; print $0}' |sed 's/ //g') # print all but last field (remove spaces)
		
			if [ "${field_chk}" == "${series_num}" 2>/dev/null ]; then
				val_series=$(printf "%0${z_pad_ser}d" $(echo "${field_value}" |grep -o '[0-9]*')) # Integers only
				scan_name+=("${val_series}")
				sub_name+=("${val_series}")
			elif [ "${field_chk}" == "${instance_num}" 2>/dev/null ]; then
				scan_name+=($(printf "%0${z_pad_ins}d" $(echo "${field_value}" |grep -o '[0-9]*'))) # Integers only
			elif [ "${field_chk}" == "${echo_num}" 2>/dev/null ]; then
				echo_val=$(echo "${field_value}" |grep -o '[0-9]*') # Integers only
				
				if ! [ -z "${echo_val}" ] && [ "${echo_val}" -gt '1' 2>/dev/null ]; then
					scan_name+=("${echo_val}") # Only include value if > 1
				fi
			else # Use field value as is
				scan_name+=("${field_value}")
			
				if [ "${#file_chk[@]}" -eq '0' ]; then
					sub_name+=("${field_value}")
				fi
			fi # if [ "${field_chk}" == "${series_num}" 2>/dev/null ]
		done # for j_dcm in ${!dcm_hdrs_input[@]}
	fi # if [ "${#dcm_fields[@]}" -ne "${#dcm_hdrs[@]}" ]
	
	if [ "${#outdir_names[@]}" -gt '0' ]; then
		outdir_vals=() # Reset array (extra output foldername)
		for j_name in ${!outdir_names[@]}; do
			outdir_name="${outdir_names[${j_name}]}"
			chk_dcm_val=($(printf "%s${IFS}" ${valid_dcm_hdrs[@]} |grep "^${outdir_name}$"))
			
			if [ "${#chk_dcm_val[@]}" -eq '0' ]; then
				outdir_vals+=("${outdir_name}") # Use value as is
			else # Search for dicom value
				dcm_val=$("${cmd_dcmdump}" "${in_dcm}" |grep " ${outdir_name}$" |awk -F '[' '{print $2}' |awk -F ']' '{print $1}' |sed "s, ,${delim},")
				vital_command "${LINENO}"
				
				if [ -z "${dcm_val}" ]; then
					echo "${red}COULD NOT DETERMINE DICOM VALUE FOR OUTPUT FOLDERNAME: ${ora}${outdir_name}${whi}"
					break # Error with dicom field(s)
				else
					outdir_vals+=("${dcm_val}")
				fi
			fi # if [ "${#chk_dcm_val[@]}" -eq '0' ]
		done # for j_name in ${!outdir_names[@]}
	fi # if [ "${#outdir_names[@]}" -gt '0' ]

	if [ "${#outdir_vals[@]}" -gt '0' ]; then
		extra_dir=$(printf "%s${delim}" ${outdir_vals[@]} |sed "s/${delim}$//g")
		final_outdir="${outdir}/${extra_dir}"
	else # No extra output folder
		final_outdir="${outdir}"
	fi # if [ "${#outdir_vals[@]}" -gt '0' ]
	
	if [ "${files_only}" == 'no' 2>/dev/null ]; then # Create subfolder
		sub_outdir=$(printf "%s${delim}" ${sub_name[@]} |sed "s/${delim}$//g")
		final_outdir="${final_outdir}/${sub_outdir}"
	fi
	
	if [ -z "${get_output_name}" ]; then # Create folder
		if ! [ -d "${final_outdir}" ]; then
			mkdir -p "${final_outdir}" 2>/dev/null
		fi
	fi
	
	dcm_filename=$(printf "%s${delim}" ${scan_name[@]} |sed "s/${delim}$//g")"${dcm_ext}"
	outfile="${final_outdir}/${dcm_filename}"
	
	if [ -z "${get_output_name}" ]; then # Rename dicom file
		if [ -f "${outfile}" ]; then # Do not overwrite files
			echo "${red}FILE ALREADY EXISTS: ${ora}${outfile}${whi}"
		else # Change filename/path
			mv "${in_dcm}" "${outfile}"
			vital_command "${LINENO}"
			change_file_perms "${final_file}"
		
			if [ "${disp_files}" == 'yes' 2>/dev/null ]; then # Display file creation
				if [ -f "${outfile}" ]; then
					echo "${gre}CREATED: ${ora}${outfile}${whi}"
				else # Unknown file creation error
					echo "${red}NOT CREATED: ${ora}${outfile}${whi}"
				fi
			fi # if [ "${disp_files}" == 'yes' 2>/dev/null ]
		fi # if [ -f "${outfile}" ]
	else # Display output name
		echo "${pur}${outfile}${whi}"
	fi
} # rename_dicom

vital_command () { # Exit script if command fails
	command_status="$?"
	command_line_number="${1}" # Must input as: vital_command ${LINENO}
	
	if ! [ -z "${command_status}" ] && [ "${command_status}" -ne '0' ]; then
		echo "${red}INVALID COMMAND: LINE ${ora}${command_line_number}${whi}"
		exit_message 97 -nh -nm -nt
	fi
} # vital_command

vital_file () { # Exit script if missing file
	for vitals; do
		if ! [ -e "${vitals}" 2>/dev/null ]; then
			bad_files+=("${vitals}")
		fi
	done
	
	if [ "${#bad_files[@]}" -gt '0' ]; then
		echo "${red}MISSING ESSENTIAL FILE(S):${whi}"
		printf "${pur}%s${IFS}${whi}" ${bad_files[@]}
		exit_message 96 -nh -nm -nt
	fi
} # vital_file

#-------------------------------- MESSAGES ---------------------------------#
control_c () { # Function activates after 'ctrl + c'
	echo "${red}FINISHING CURRENT BACKGROUND PROCESSES BEFORE CRASHING${whi}"
	exit_message 95 -nh -nt
} # control_c

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
		elif [ "${exit_inputs}" == '-nt' 2>/dev/null ]; then
			show_time='no'
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
	
	# Display script process time
	if [ "${show_time}" == 'yes' 2>/dev/null ]; then # Script time message
		time_func 2>/dev/null
	fi
	
	printf "${formatreset}\n"
	IFS="${IFS_old}" # Reset IFS
	exit "${exit_type}"
} # exit_message

time_func () { # Script process time calculation
	func_end_time=$(date +%s) # Time in seconds
	input_time="${1}"
	valid_time='yes'
	
	if ! [ -z "${input_time}" ] && [ "${input_time}" -eq "${input_time}" 2>/dev/null ]; then
		func_start_time="${input_time}"
	elif ! [ -z "${start_time}" ] && [ "${start_time}" -eq "${start_time}" 2>/dev/null ]; then
		func_start_time="${start_time}"
	else # If no integer input or 'start_time' undefined
		valid_time='no'
	fi
	
	if [ "${valid_time}" == 'yes' ]; then
		process_time=$((${func_end_time} - ${func_start_time}))
		days=$((${process_time} / 86400))
		hours=$((${process_time} % 86400 / 3600))
		mins=$((${process_time} % 3600 / 60))
		secs=$((${process_time} % 60))
	
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
	fi # if [ "${valid_time}" == 'yes' ]
} # time_func

#---------------------------------- CODE -----------------------------------#
trap control_c SIGINT 2>/dev/null # Finishes background processes before crashing
script_path=$(mac_readlink "${script_path}") # similar to 'readlink -f' in linux

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
	exit_message 0 -nm -nt
fi

check_bad_inputs # Exit script if invalid inputs
if [ "${disp_alert}" == 'yes' 2>/dev/null ]; then
	echo "${ora}CHECKING SCRIPT AND INPUT VALUES${whi}"
fi

# Check commands
cmd_dcmdump=$(which dcmdump) # Find 'dcmdump' path
cmd_file=$(which file) # Find 'file' path
if [ -z "${cmd_dcmdump}" ]; then
	if ! [ -z "${def_dcmdump}" ] && [ -f "${def_dcmdump}" ]; then
		cmd_dcmdump="${def_dcmdump}"
	else # Cannot find 'dcmdump'
		echo "${red}MISSING COMMAND: ${ora}dcmdump${whi}"
		echo "${ora}DOWNLOAD DICOM Toolkit: ${gre}${dcmtoolkit_page}${whi}"
		exit_message 1 -nt
	fi
fi # if [ -z "${cmd_dcmdump}" ]

if [ -z "${cmd_file}" ]; then
	if ! [ -z "${def_file}" ] && [ -f "${def_file}" ]; then
		cmd_file="${def_file}"
	else # Cannot find 'file'
		echo "${red}MISSING COMMAND: ${ora}file${whi}"
		exit_message 2 -nt
	fi
fi # if [ -z "${cmd_file}" ]

# Check folder inputs
if [ "${#input_dirs[@]}" -eq '0' ] && [ "${#input_files[@]}" -eq '0' ]; then
	input_dirs=($(pwd)) # Get files from working directory
fi

if [ -z "${outdir}" ]; then
	outdir=$(pwd) # Working directory becomes output folder
fi

if ! [ -d "${outdir}" ]; then # Output folder must exist
	echo "${red}MISSING OUTPUT FOLDER: ${ora}${outdir}${whi}"
	exit_message 3 -nt
fi

# Assign defaults (if necessary)
if [ -z "${delim}" ]; then # -del
	delim="${def_delim}" # Default delimiter
fi

if [ -z "${search_depth}" ]; then # -m
	search_depth="${def_search_depth}" # Default search depth
fi

if [ -z "${dir_perm}" ]; then # -pd
	check_perm "${def_dir_perm}"
	dir_perm="${def_dir_perm}" # Default directory permissions
fi

if [ -z "${file_perm}" ]; then # -pf
	check_perm "${def_file_perm}"
	file_perm="${def_file_perm}" # Default file permissions
fi

if ! [ -z "${s_in_count}" ] && [ "${s_in_count}" -eq '0' 2>/dev/null ]; then # -s
	disp_ver='no' # Default to suppress verification message
fi

if [ -z "${z_pad_ins}" ]; then # -zi
	z_pad_ins="${def_z_pad_ins}" # Default instance number zero pad
fi

if [ -z "${z_pad_ser}" ]; then # -zs
	z_pad_ser="${def_z_pad_ser}" # Default series number zero pad
fi

if [ "${#dcm_hdrs[@]}" -eq '0' ]; then
	dcm_hdrs=($(printf "%s${IFS}" ${def_dcm_hdrs[@]})) # Use printf to avoid $IFS errors
fi

# Check for essential values: echo/instance/series number (must be included)
chk_echo_num=($(printf "%s${IFS}" ${dcm_hdrs[@]} |grep "^${echo_num}$"))
chk_inst_num=($(printf "%s${IFS}" ${dcm_hdrs[@]} |grep "^${instance_num}$"))
chk_series_num=($(printf "%s${IFS}" ${dcm_hdrs[@]} |grep "^${series_num}$"))
if [ "${#chk_series_num[@]}" -eq '0' ]; then # Place series number at front
	dcm_hdrs=($(printf "%s${IFS}" "${series_num}" ${dcm_hdrs[@]}))
fi # Series number

if [ "${#chk_inst_num[@]}" -eq '0' ]; then # Place instance number at back
	dcm_hdrs+=("${instance_num}")
fi # Instance number

if [ "${#chk_echo_num[@]}" -eq '0' ]; then # Place echo number behind instance number
	dcm_hdrs+=("${echo_num}")
fi # Echo number

check_bad_inputs # Exit script if invalid inputs

for i in ${!input_dirs[@]}; do # Loop thru input folders
	input_files+=($(find "${input_dirs[${i}]}" -maxdepth "${search_depth}" -type f)) # Find all files
done

if [ "${disp_alert}" == 'yes' 2>/dev/null ]; then
	echo "${ora}FINDING DICOM FILES FROM ${gre}${#input_files[@]} ${ora}INPUT FILES${whi}"
fi # if [ "${disp_alert}" == 'yes' 2>/dev/null ]

start_index='0'
until [ "${start_index}" -ge "${#input_files[@]}" ]; do # limit inputs to 'file'
	dcm_files+=($("${cmd_file}" $(printf "${input_files[*]:${start_index}:${chk_file_count}}") |grep "${dcm_grep}" |awk -F ':' '{$NF=""; print $0}' |sed 's/ $//g'))
	start_index=$((${start_index} + ${chk_file_count}))
done

if [ "${#dcm_files[@]}" -eq '0' ]; then
	echo "${red}NO DICOM FILES FOUND${whi}"
	exit_message 4 -nt
fi # if [ "${#dcm_files[@]}" -eq '0' ]

if [ "${disp_ver}" == 'yes' 2>/dev/null ]; then
	if ! [ "${verify_time}" -ge '1' 2>/dev/null ]; then
		verify_time='1' # Default to '1' to avoid errors
	fi
	
	echo "${ora}FOUND ${gre}${#dcm_files[@]} ${ora}DICOM FILES${whi}"
	echo "${whi}---------------${whi}" # Space out display values
	
	if [ "${#outdir_names[@]}" -gt '0' ]; then # Add main folder to output path
		for i in ${!outdir_names[@]}; do # Loop thru name portions of main folder
			outdir_name="${outdir_names[${i}]}"
			chk_dcm_hdr=($(printf "%s${IFS}" ${valid_dcm_hdrs[@]} |grep "^${outdir_name}$")) # Check if dicom value
			if [ "${#chk_dcm_hdr[@]}" -gt '0' ]; then # Display dicom headers in green
				disp_outname="${disp_outname}${gre}${outdir_name}${whi}${delim}" # Display name for verification
			else # non-dicom header input, display value in orange
				disp_outname="${disp_outname}${ora}${outdir_name}${whi}${delim}" # Display name for verification
			fi # if [ "${#chk_dcm_hdr[@]}" -gt '0' ]
		done # for i in ${!outdir_names[@]}
		
		disp_outname=$(echo "${disp_outname}" |sed "s,${delim}$,,")"${whi}" # Remove trailing delimiter
		echo "${ora}OUTPUT FOLDER   : ${pur}${outdir}/${disp_outname}${whi}"
	else # Do not include extra folder
		echo "${ora}OUTPUT FOLDER   : ${pur}${outdir}${whi}"
	fi # if [ "${#outdir_names[@]}" -gt '0' ]
	
	if [ "${files_only}" == 'no' 2>/dev/null ]; then # Include scan subfolder
		for i in ${!dcm_hdrs[@]}; do # Loop thru dicom headers
			dcm_hdr="${dcm_hdrs[${i}]}"
			chk_dcm_hdr_file=($(printf "%s${IFS}" ${file_dcm_hdrs[@]} |grep "^${dcm_hdr}$")) # Exclude file headers
			
			if [ "${#chk_dcm_hdr_file[@]}" -eq '0' ]; then # Series/study headers only
				disp_subfolder="${disp_subfolder}${gre}${dcm_hdr}${whi}${delim}"
			fi
		done # for i in ${!dcm_hdrs[@]}
	
		disp_subfolder=$(echo "${disp_subfolder}" |sed "s,${delim}$,,")"${whi}" # Remove trailing delimiter
		echo "${ora}OUTPUT SUBFOLDER: ${disp_subfolder}${whi}"
	fi # if [ "${files_only}" == 'no' 2>/dev/null ]
	
	# Setup file output display
	for i in ${!dcm_hdrs[@]}; do
		disp_dcm_hdr="${disp_dcm_hdr}${gre}${dcm_hdrs[${i}]}${whi}${delim}"
	done

	disp_dcm_hdr=$(echo "${disp_dcm_hdr}" |sed "s,${delim}$,,")"${whi}${dcm_ext}" # Remove trailing delimiter
	echo "${ora}OUTPUT FILENAME : ${disp_dcm_hdr}${whi}"
	
	if [ "${change_perm}" == 'yes' 2>/dev/null ]; then
		echo "${ora}DICOM FILE PERMISSIONS  : ${gre}${file_perm}${whi}"
		echo "${ora}DICOM FOLDER PERMISSIONS: ${gre}${dir_perm}${whi}"
	else # Alert user that permissions will not be changed
		echo "${ora}NOT CHANGING FILE/FOLDER PERMISSIONS${whi}"
	fi
	
	echo "${ora}LEADING ZEROS (${gre}${series_num}${ora})  : ${gre}${z_pad_ser}${whi}"
	echo "${ora}LEADING ZEROS (${gre}${instance_num}${ora}): ${gre}${z_pad_ins}${whi}"
	
	echo "${whi}---------------${whi}" # Space out display values
	echo "${gre}EXAMPLE OUTPUT FOR${whi}: ${ora}${dcm_files[0]}${whi}"
	rename_dicom "${dcm_files[0]}" 'EXAMPLE' # Display first dicom file as an example
	echo "${whi}---------------${whi}" # Space out display values
	
	echo "${ora}INPUT ${gre}ctrl${ora}+${gre}c ${ora}TO CRASH${whi}"
	printf "${ora}STARTING IN: ${whi}"
	for i in $(seq "${verify_time}" -1 1); do # Loop thru seconds
		printf "${pur}${i} ${whi}" # Display number of seconds before processing
		sleep 1 # Wait 1 second
	done
fi # if [ "${disp_ver}" == 'yes' 2>/dev/null ]

if [ "${disp_alert}" == 'yes' 2>/dev/null ]; then
	echo "${ora}RENAMING DICOM FILES: ${gre}${outdir}${whi}" # Alert user of script start
fi # if [ "${disp_alert}" == 'yes' 2>/dev/null ]

count_thresh="${rename_alert}"
for i in ${!dcm_files[@]}; do
	rename_dicom "${dcm_files[${i}]}" &
	control_bg_jobs
	
	if [ "${disp_alert}" == 'yes' 2>/dev/null ] && [ "${i}" -eq "${count_thresh}" ]; then
		echo "${whi}----------${whi}"
		echo "${pur}${count_thresh}${ora}/${pur}${#dcm_files[@]} ${ora}FILES RENAMED${whi}"
		echo "${whi}----------${whi}"
		count_thresh=$((${count_thresh} + ${rename_alert}))
	fi # Alert user of renaming progress
done # for i in ${!dcm_files[@]}

exit_message 0