#!/bin/sh

# Author: Konstantin Lübeck

# Settings
## path to the binaries of vdirsyncer and ppl
VDS="/usr/bin/vdirsyncer"
PPL="/usr/bin/ppl"

## path to locations where vdirsyncer and ppl store their vcf files
VDS_CONTACTS="~/.vdirsyncer/contacts"
PPL_CONTACTS="~/.ppl/contacts"

## path to file which stores when the last execution of the program took place
FILE_LAST_SYNC_TIME="~/.lastsynctime"


# Checks
## does path to vdirsyncer exist
if [ ! -f ${VDS} ]; then
    >&2 echo "ERROR: Path to vdirsyncer 'VDS=${VDS}' does not exist"
    exit 1
fi

if [ ! -f ${PPL} ]; then
    >&2 echo "ERROR: Path to ppl 'PPL=${PPL}' does not exist"
    exit 1
fi

if [ ! -d ${VDS_CONTACTS} ]; then
    >&2 echo "ERROR: Path to ppl's contacts repositroy 'VDS_CONTACTS=${VDS_CONTACTS}' does not exist"
    exit 1
fi

if [ ! -d ${PPL_CONTACTS} ]; then
    >&2 echo "ERROR: Path to ppl's contacts repositroy 'PPL_CONTACTS=${PPL_CONTACTS}' does not exist"
    exit 1
fi

if [ ! -f ${FILE_LAST_SYNC_TIME} ]; then
    >&2 echo "ERROR: Path to file with the last sync 'FILE_LAST_SYNC_TIME=${FILE_LAST_SYNC_TIME}' does not exist"
    exit 1
fi


# sync vdirsyncer
echo " * Syncing vdirsyncer."
"${VDS}" sync > /dev/null

# check if vcf files present in the vdirsyncer's repository are also present in
# ppl's repository
for VCF_FILE in $(ls "${VDS_CONTACTS}"); do

    VDS_VCF_FILE="${VDS_CONTACTS}/${VCF_FILE}"
    PPL_VCF_FILE="${PPL_CONTACTS}/${VCF_FILE}"
    VCF_TOKEN=${VCF_FILE%.*}

    if [ ! -f "${PPL_VCF_FILE}" ]; then

        # check if it was removed by ppl
        if [ ! "0" -eq "$(git -C "${PPL_CONTACTS}" log --pretty=format:%s | grep "remove_contact(${VCF_TOKEN})" | wc -l)" ]; then
            # if the vcf file was removed by ppl then remove it from vdirsyncer
            rm "${VDS_VCF_FILE}"
            echo " * ${VCF_FILE} was removed from vdirsyncer's repository."
        else 
            # if the vcf file was not removed by ppl then copy it to ppl's repository
            cp "${VDS_VCF_FILE}" "${PPL_VCF_FILE}"
            git -C "${PPL_CONTACTS}" add "${PPL_VCF_FILE}"  > /dev/null
            git -C "${PPL_CONTACTS}" commit -am "save_contact(${VCF_TOKEN})" > /dev/null
            echo " * ${VCF_FILE} was added to ppl's repository."
        fi
    fi
done

# check if vcf files present in the ppl's repository are also present in
# vdirsyncers's repository
for VCF_FILE in $(ls "${PPL_CONTACTS}"); do

    VDS_VCF_FILE="${VDS_CONTACTS}/${VCF_FILE}"
    PPL_VCF_FILE="${PPL_CONTACTS}/${VCF_FILE}"
    VCF_TOKEN=${VCF_FILE%.*}

    if [ ! -f "${VDS_VCF_FILE}" ]; then
        
        # check if file was saved in ppl's repository
        if [ ! "0" -eq "$(git -C "${PPL_CONTACTS}" log --pretty=format:%s | grep "save_contact(${VCF_TOKEN})" | wc -l)" ]; then

            # get last save date of file
            LAST_SAVE_DATE=$(git -C "${PPL_CONTACTS}" log --pretty=format:%ct%n%s | grep -B 1 "save_contact(${VCF_TOKEN})" | head -n1)

            # if last save date is later than the last sync date than it will
            # be stored in vdirsyncer's repository
            if [ "${LAST_SAVE_DATE}" -gt "$(cat ${FILE_LAST_SYNC_TIME})" ]; then
                cp "${PPL_VCF_FILE}" "${VDS_VCF_FILE}"
                echo " * ${VCF_FILE} was added to vdirsyncer's repository."

            # if last save date is befor the last sync date than it will be
            # deleted from ppl's repository
            else
                PWD=$(pwd)
                cd "${PPL_CONTACTS}"
                ppl rm "${VCF_TOKEN}"
                cd "${PWD}"
                echo " * ${VCF_FILE} was removed from ppl's repository."
            fi

        else
            # file is not stored in ppl's repository ignore it
            echo " * ${VCF_FILE} was never saved in ppl's repository. It will be ignored."
        fi
    fi
done

# check if vcf files in ppl's and vdirsyncer's repositories differ from each other
for VCF_FILE in $(ls "${VDS_CONTACTS}"); do

    VDS_VCF_FILE="${VDS_CONTACTS}/${VCF_FILE}"
    PPL_VCF_FILE="${PPL_CONTACTS}/${VCF_FILE}"
    VCF_TOKEN=${VCF_FILE%.*}

    # if the files differ from each other the file with the later modification
    # date will be used
    # TODO: merge
    if [ ! "0" -eq $(diff ${VDS_VCF_FILE} ${PPL_VCF_FILE} | wc -l) ]; then

        if [[ $(uname) == "Darwin" ]]; then
            VDS_VCF_FILE_MODIFATION_DATE=$(stat -f "%m" ${VDS_VCF_FILE})
        else
            VDS_VCF_FILE_MODIFATION_DATE=$(stat -c %Y ${VDS_VCF_FILE})
        fi

        PPL_VCF_FILE_LAST_SAVE_DATE=$(git -C "${PPL_CONTACTS}" log --pretty=format:%ct%n%s | grep -B 1 "save_contact(${VCF_TOKEN})" | head -n1)

        # latest version is stored in ppl's repository
        if [ "${PPL_VCF_FILE_LAST_SAVE_DATE}" -gt "${VDS_VCF_FILE_MODIFATION_DATE}" ]; then
            cp -f "${PPL_VCF_FILE}" "${VDS_VCF_FILE}"
            echo " * ${VCF_FILE} was updated in vdirsyncer's repository."
        # latest version is stored in vdirsyncer's repository
        else
            cp -f "${VDS_VCF_FILE}" "${PPL_VCF_FILE}"
            git -C "${PPL_CONTACTS}" add "${PPL_VCF_FILE}"  > /dev/null
            git -C "${PPL_CONTACTS}" commit -am "save_contact(${VCF_TOKEN})" > /dev/null
            echo " * ${VCF_FILE} was updated in ppl's repository."
        fi
    fi
done

echo " * Syncing vdirsyncer."
"${VDS}" sync > /dev/null

# store current date and time as last sync time
printf "$(date "+%s")" > ${FILE_LAST_SYNC_TIME}

echo " * Done."
