#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/rhcs/acceptance/cli-tests/pki-cert-cli
#   Description: PKI CERT CLI tests
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The following pki cert cli commands needs to be tested:
#  pki-cert-request-submit
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Author: Niranjan Mallapadi <mrniranjan@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include rhts environment
. /usr/bin/rhts-environment.sh
. /usr/share/beakerlib/beakerlib.sh
. /opt/rhqa_pki/rhcs-shared.sh
. /opt/rhqa_pki/pki-cert-cli-lib.sh
. /opt/rhqa_pki/env.sh

run_pki_cert_show()
{

	local invalid_serialNumber=$(cat /dev/urandom | tr -dc '1-9' | fold -w 10 | head -n 1)
	CA_agentV_user=CA_agentV
	local pkcs10_reqstatus
	local pkcs10_requestid
	local crmf_reqstatus
	local crmf_requestid
	local decimal_valid_serialNumber

	local rand=$(cat /dev/urandom | tr -dc '0-9' | fold -w 5 | head -n 1)
	local invalid_hex_serialNumber=$(expr $valid_pkcs10_serialNumber$rand)
	local junk="axb124?$5@@_%^$#$@\!(_)043112321412321"

	# Creating Temporary Directory for pki cert-show

        rlPhaseStartSetup "pki cert-show Temporary Directory"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlPhaseEnd
	
	# Create a Temporary NSS DB Directory and generate Certificate

	rlPhaseStartSetup "Generating temporary Cert to be used pki cert-show automation Tests"
        local TEMP_NSS_DB="$TmpDir/nssdb"
	local temp_out="$TmpDir/cert-show.out"
        rlRun "create_cert_request $TEMP_NSS_DB redhat pkcs10 rsa 2048 "--" "--" "--" "--" "--" "--" "--" "pkcs10_reqstatus" "pkcs10_requestid" "pkcs10_requestdn""
        rlRun "pki -d $CERTDB_DIR -c $CERTDB_DIR_PASSWORD -n \"$CA_agentV_user\" ca-cert-request-review $pkcs10_requestid --action approve 1> $TmpDir/pki-pkcs10-approve-out" 0 "As $CA_agentV_user Approve Certificate Request"
	rlAssertGrep "Approved certificate request $pkcs10_requestid" "$TmpDir/pki-pkcs10-approve-out"
	rlRun "create_cert_request $TEMP_NSS_DB redhat crmf rsa 2048 "--" "--" "--" "--" "--" "--" "--" "crmf_reqstatus" "crmf_requestid" "crmf_requestdn""
	rlRun "pki -d $CERTDB_DIR \
			-c $CERTDB_DIR_PASSWORD \
			-n \"$CA_agentV_user\" \
			ca-cert-request-review $crmf_requestid \
			--action approve 1> $TmpDir/pki-crmf-approve-out"
	rlAssertGrep "Approved certificate request $crmf_requestid" "$TmpDir/pki-crmf-approve-out"
	rlRun "valid_pkcs10_serialNumber=\$(pki cert-request-show $pkcs10_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)" 0 \
		"Get SerialNumber of Approved pkcs10 Request"
	rlRun "valid_crmf_serialNumber=\$(pki cert-request-show $crmf_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)" 0 \
		"Get SerialNumber of Approved crmf Requests"
        rlPhaseEnd

	# pki cert cli config test

	rlPhaseStartTest "pki_cert_cli-configtest: pki cert-show --help configuration test"
	rlRun "pki cert-show --help > $TmpDir/cert-show.out 2>&1" 0 "pki cert-show --help"
	rlAssertGrep "usage:" "$TmpDir/cert-show.out"
    	rlAssertGrep "--encoded         Base-64 encoded" "$TmpDir/cert-show.out"
    	rlAssertGrep "--output <file>   Output file" "$TmpDir/cert-show.out"
    	rlAssertGrep "--pretty          Pretty print" "$TmpDir/cert-show.out"
	rlAssertNotGrep "Error: Unrecognized option: --help" "$TmpDir/cert-show.out"
	rlLog "FAIL :: https://engineering.redhat.com/trac/pki-tests/ticket/490"
	rlPhaseEnd


	#Run pki cert-show with valid serial number in HexaDecimal

	rlPhaseStartTest "pki_cert_show-001: pki cert-show < valid serialNumber(HexaDecimal) >  should show Certificate Details"
	rlRun "pki cert-show $valid_pkcs10_serialNumber > $temp_out" 0 "Executing pki cert-show $valid_pkcs10_serialNumber"
	rlAssertGrep "Certificate \"$valid_pkcs10_serialNumber\"" "$temp_out"
	rlAssertGrep "Serial Number: $valid_pkcs10_serialNumber" "$temp_out"
	rlAssertGrep "Issuer: CN=CA Signing Certificate,O=$CA_DOMAIN" "$temp_out"	
	rlAssertGrep "Subject: $pkcs10_requestdn" "$temp_out"
	rlAssertGrep "Status: VALID" "$temp_out"
	rlPhaseEnd

	#Run pki cert-show with No serial Number 

	rlPhaseStartTest "pki_cert_show-002: pki cert-show should fail when no serial Number is given"
	rlRun "pki cert-show  > $temp_out" 1 "pki cert-show without any serial number fails"
	rlAssertGrep "usage: cert-show" "$temp_out"
	rlPhaseEnd
	
	# Run pki cert-show with Invalid Serial Number in decimal

	rlPhaseStartTest "pki_cert_show-003: pki cert-show < invalid serialNumber(Decimal) > should Fail"
	rlRun "pki cert-show $invalid_serialNumber 2> $temp_out" 1 "command pki cert-show $serialNumber"
	rlAssertGrep "CertNotFoundException" "$temp_out"
	rlPhaseEnd

	# Run pki cert-show with valid serial Number given in decimal 
	rlPhaseStartTest "pki_cert_show-004: pki cert-show < valid serialNumber(Decimal) > should show Certificate Details"
	local decimal_valid_serialNumber=$(printf %d $valid_pkcs10_serialNumber)
	rlRun "pki cert-show $decimal_valid_serialNumber > $temp_out" 0 "Executing pki cert-show $decimal_valid_serialNumber"
	rlAssertGrep "Certificate \"$valid_pkcs10_serialNumber\"" "$temp_out"
	rlAssertGrep "Serial Number: $valid_pkcs10_serialNumber" "$temp_out"
	rlAssertGrep "Issuer: CN=CA Signing Certificate,O=$CA_DOMAIN" "$temp_out"
	rlAssertGrep "Subject: $pkcs10_requestdn" "$temp_out"
	rlAssertGrep "Status: VALID" "$temp_out"
	rlPhaseEnd

	#Run pki cert-show with invalid serialNumber given in Hexadecimal
	
	rlPhaseStartTest "pki_cert_show-005: pki cert-show < invalid serialNumber(hexadecimal) > should fail"
	rlRun "pki cert-show $invalid_serialNumber 2> $temp_out" 1 "Executing pki cert-show $serialNumber"
	rlAssertGrep "CertNotFoundException" "$temp_out"
	rlPhaseEnd

	# Run pki cert-show with Junk Characters

	rlPhaseStartTest "pki_cert_show-006: pki cert-show < junk characters > should fail to show any certificate Details"
	rlRun "pki cert-show \"$junk\" 2> $temp_out" 1 "Executing pki cert-show $junk"
	rlAssertGrep "NumberFormatException: For input string" "$temp_out"
	rlPhaseEnd	
	
	# Run pki cert-show <valid serialNumber> --encoded to produce a valid pem output

	rlPhaseStartTest "pki_cert_show-007: pki cert-show <valid SerialNumber>  --encoded should produce a valid pem output"
	rlLog "Running pki cert-show $valid_pkcs10_serialNumber"
        rlRun "pki cert-show $valid_pkcs10_serialNumber --encoded > $temp_out" 0 "command pki cert-show $serialNumber --encoded"
        rlLog "Get the Subject Name of the Certificate with $valid_pkcs10_serialNumber"
        rlLog "$(cat $temp_out | grep Issuer | awk -F":" '{print $2}')"
	rlRun "openssl x509 -in $temp_out -noout -serial 1> $temp_out-openssl" 0 "Run openssl x509 pki cert-show --encoded"
	rlAssertGrep "serial=$(echo $valid_pkcs10_serialNumber|sed 's/x//g')" "$temp_out-openssl"
	rlPhaseEnd
	
	#Run pki cert-show --encoded with No serial Number

	rlPhaseStartTest "pki_cert_show-008: pki cert-show <No SerialNumber> --encoded should fail"
	rlRun "pki cert-show --encoded 1> $temp_out" 1 "Running pki cert-show <No-serial-Number> --encoded"
	rlAssertGrep "usage: cert-show" "$temp_out"
	rlPhaseEnd
	
	# Run pki cert-show --encoded with Invalid Serial Number

	rlPhaseStartTest "pki_cert_show-009: pki cert-show <In-Valid SerialNumber> --encoded should fail"
	rlLog "Running pki cer-show <invalid-serial-Number> --encoded"
	rlRun "pki cert-show $invalid_serialNumber --encoded 2> $temp_out" 1 "pki cert-show $serialNumber"
	rlPhaseEnd
	
	# Run pki cert-show <valid serialNumber> --output <filename>(pkcs10)

	rlPhaseStartTest "pki_cert_show-0010: pki cert-show <valid SerialNumber(decimal)> --output <filename> should save the Certificate in File"
	rlRun "pki cert-show $valid_pkcs10_serialNumber --output $temp_out" 0 "Executing pki cert-show $valid_pkcs10_serialNumber --output <file-name>"
	rlAssertGrep "-----BEGIN CERTIFICATE-----" "$temp_out"
	rlAssertGrep "\-----END CERTIFICATE-----" "$temp_out"
	rlRun "openssl x509 -in $temp_out -noout -serial 1> $temp_out-openssl" 0 "Run openssl x509 on the output file"
	rlAssertGrep "serial=$(echo $valid_pkcs10_serialNumber|sed 's/x//g')" "$temp_out-openssl"
	rlPhaseEnd

	#Run pki cert-show <valid serialNumber> --output <filename> (crmf)

	rlPhaseStartTest "pki_cert_show-0011: pki cert-show <valid SerialNumber(Decimal)> (crmf) --output <filename> should save the Certificate in File"
	rlRun "pki cert-show $valid_crmf_serialNumber --output $temp_out" 0 "Executing pki cert-show $valid_crmf_serialNumber --output <file-name>"
	rlAssertGrep "-----BEGIN CERTIFICATE-----" "$temp_out"
	rlAssertGrep "\-----END CERTIFICATE-----" "$temp_out"
	rlRun "openssl x509 -in $temp_out -noout -serial 1> $temp_out-openssl" 0 "Run openssl x509 on the output file"
	rlAssertGrep "serial=$(echo $valid_pkcs10_serialNumber|sed 's/x//g')" "$temp_out-openssl"
	rlPhaseEnd
	
	# Run pki cert-show <invalid-serial-number> --output 

	rlPhaseStartTest "pki_cert_show-0012: pki cert-show <invalid-serial-Number> --output <filename> should not create any file"
	rlLog "Running pki cert-show <invalid-serialNumber> --output <filename>"
	rlRun "pki cert-show $invalid_serialNumber --output $temp_out" 1 "pki cert-show <invalid-serial-number> --output <file>"
	if $(test -f $temp_out); then
		rlPass "$temp_out exists"	
	else 
		rlFail "$temp_out doesn't exist"
	fi
	rlPhaseEnd

	# Run pki cert-show <No serial number> --output <filename>

	rlPhaseStartTest "pki_cert_show-0013: pki cert-show <No serialNumber> --output <filename> should fail"
	local temp_out13=$TmpDir/cert-show13.out
	local temp_out13_err=$TmpDir/cert-err13.out
	rlLog "Running pki cert-show --output $temp_out13 1> $temp_out13_err" 
	rlRun "pki cert-show --output $temp_ou13 1> $temp_out13_err" 1
	rlAssertGrep "usage:" "$temp_out13_err"  	
	rlAssertGrep "--encoded         Base-64 encoded" "$temp_out13_err"
	rlAssertGrep "--output <file>   Output file" "$temp_out13_err"
	rlAssertGrep "--pretty          Pretty print" "$temp_out13_err"	
	rlPhaseEnd	
	
	
	# Run pki cert-show <valid-serial-number> --pretty 

        rlPhaseStartTest "pki_cert_show-0014: pki cert-show <valid SerialNumber(decimal)> --pretty <filename> should show PrettyPrint output of cert and save the the Cert in File."
        rlLog "Running pki cert-show $valid_pkcs10_serialNumber --pretty"
        rlRun "pki cert-show $valid_pkcs10_serialNumber --pretty > $temp_out" 0
        rlAssertGrep "Certificate:" "$temp_out"
        rlAssertGrep "Version:" "$temp_out"
	rlAssertGrep "Subject:" "$temp_out"
        rlPhaseEnd

	 # Run pki cert-show <in-valid-serial-number> --pretty 

	rlPhaseStartTest "pki_cert_show-0015: pki cert-show < $invalid_serialNumber > --pretty <filename> should fail to produce any PrettyPrint output"
	rlRun "pki cert-show $invalid_serialNumber --pretty 2> $temp_out" 1 "Executing pki cert-show $invalid_serialNumber --pretty"
	rlAssertGrep "CertNotFoundException: Certificate ID 0x$(printf %x $invalid_serialNumber) not found" "$temp_out"
	rlPhaseEnd

	# Run pki cert-show <No serial Number> --pretty

	rlPhaseStartTest "pki_cert_show-0016: pki cert-show <No serialNumber> --pretty <filename> should fail to produce any PrettyPrint output"
	rlLog "Running pki cert-show --pretty" 1
	rlRun "pki cert-show --pretty 1> $temp_out" 1
	rlAssertGrep "usage:" "$temp_out"
	rlAssertGrep "--encoded         Base-64 encoded" "$temp_out"
	rlAssertGrep "--output <file>   Output file" "$temp_out"
	rlAssertGrep "--pretty          Pretty print" "$temp_out" 
	rlPhaseEnd

	# Run pki cert-show with i18n characters 
	
	rlPhaseStartTest "pki_cert_show-0017: Verify pki cert-show \"CN=Örjan Äke,UID=Örjan Äke\" i18n Characters"
	rlRun "create_cert_request $TEMP_NSS_DB redhat pkcs10 rsa 2048 \"Örjan Äke\" \"Örjan Äke\" \"test@example.org\" "--" "--" "--" "--" "i18n_ret_reqstatus" "i18n_ret_requestid""
	rlRun "pki -d $CERTDB_DIR \
		-c $CERTDB_DIR_PASSWORD \
		-n \"$CA_agentV_user\" \
		ca-cert-request-review $i18n_ret_requestid \
		--action approve 1> $TmpDir/i18n-pkcs10-approve-out" 0 "As $CA_agentV_user Approve Certificate Request"
	rlAssertGrep "Approved certificate request $i18n_ret_requestid" "$TmpDir/i18n-pkcs10-approve-out"
	rlRun "valid_i18n_pkcs10_serialNumber=\$(pki cert-request-show $i18n_ret_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)"
	rlRun "pki cert-show $valid_i18n_pkcs10_serialNumber 1> $temp_out" 0 "Executing pki cert-show $valid_i18n_valid_pkcs10_serialNumber"
	rlAssertGrep "CN=Örjan Äke" "$temp_out"
	rlAssertGrep "UID=Örjan Äke" "$temp_out"
	rlPhaseEnd
	
	rlPhaseStartTest "pki_cert_show-0018: Verify pki cert-show \"CN=Éric Têko,UID=Éric Têko\" i18n Characters"
	rlRun "create_cert_request $TEMP_NSS_DB redhat pkcs10 rsa 2048 \"Éric Têko\" \"Éric Têko\" \"test@example.org\" "--" "--" "--" "--" "i18n_ret_reqstatus" "i18n_ret_requestid""
	rlRun "pki -d $CERTDB_DIR \
		-c $CERTDB_DIR_PASSWORD \
		-n \"$CA_agentV_user\" \
		ca-cert-request-review $i18n_ret_requestid \
		--action approve 1> $TmpDir/i18n-pkcs10-approve-out" 0 "As $CA_agentV_user Approve Certificate Request"
	rlAssertGrep "Approved certificate request $i18n_ret_requestid" "$TmpDir/i18n-pkcs10-approve-out"
	rlRun "valid_i18n_pkcs10_serialNumber=\$(pki cert-request-show $i18n_ret_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)"
	rlRun "pki cert-show $valid_i18n_pkcs10_serialNumber 1> $temp_out" 0 "Executing pki cert-show $valid_i18n_valid_pkcs10_serialNumber"
	rlAssertGrep "CN=Éric Têko" "$temp_out"
	rlAssertGrep "UID=Éric Têko" "$temp_out"
	rlPhaseEnd 


	rlPhaseStartTest "pki_cert_show-0018: Verify pki cert-show \"CN=éénentwintig dvidešimt,UID=éénentwintig dvidešimt\" i18n Characters"
	rlRun "create_cert_request $TEMP_NSS_DB redhat pkcs10 rsa 2048 \"éénentwintig dvidešimt\" \"éénentwintig dvidešimt\" \"test@example.org\" "--" "--" "--" "--" "i18n_ret_reqstatus" "i18n_ret_requestid""
	rlRun "pki -d $CERTDB_DIR \
		-c $CERTDB_DIR_PASSWORD \
		-n \"$CA_agentV_user\" \
		ca-cert-request-review $i18n_ret_requestid \
		--action approve 1> $TmpDir/i18n-pkcs10-approve-out" 0 "As $CA_agentV_user Approve Certificate Request"
	rlAssertGrep "Approved certificate request $i18n_ret_requestid" "$TmpDir/i18n-pkcs10-approve-out"
	rlRun "valid_i18n_pkcs10_serialNumber=\$(pki cert-request-show $i18n_ret_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)"
	rlRun "pki cert-show $valid_i18n_pkcs10_serialNumber 1> $temp_out" 0 "Executing pki cert-show $valid_i18n_valid_pkcs10_serialNumber"
	rlAssertGrep "CN=éénentwintig dvidešimt" "$temp_out"
	rlAssertGrep "UID=éénentwintig dvidešimt" "$temp_out"
	rlPhaseEnd 


	rlPhaseStartTest "pki_cert_show-0018: Verify pki cert-show \"CN=kakskümmend üks,UID=kakskümmend üks\" i18n Characters"
	rlRun "create_cert_request $TEMP_NSS_DB redhat pkcs10 rsa 2048 \"kakskümmend üks\" \"kakskümmend üks\" \"test@example.org\" "--" "--" "--" "--" "i18n_ret_reqstatus" "i18n_ret_requestid""
	rlRun "pki -d $CERTDB_DIR \
		-c $CERTDB_DIR_PASSWORD \
		-n \"$CA_agentV_user\" \
		ca-cert-request-review $i18n_ret_requestid \
		--action approve 1> $TmpDir/i18n-pkcs10-approve-out" 0 "As $CA_agentV_user Approve Certificate Request"
	rlAssertGrep "Approved certificate request $i18n_ret_requestid" "$TmpDir/i18n-pkcs10-approve-out"
	rlRun "valid_i18n_pkcs10_serialNumber=\$(pki cert-request-show $i18n_ret_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)"
	rlRun "pki cert-show $valid_i18n_pkcs10_serialNumber 1> $temp_out" 0 "Executing pki cert-show $valid_i18n_valid_pkcs10_serialNumber"
	rlAssertGrep "CN=kakskümmend üks" "$temp_out"
	rlAssertGrep "UID=kakskümmend üks" "$temp_out"
	rlPhaseEnd 
	
	rlPhaseStartTest "pki_cert_show-0018: Verify pki cert-show \"CN=двадцять один тридцять,UID=двадцять один тридцять\" i18n Characters"
	rlRun "create_cert_request $TEMP_NSS_DB redhat pkcs10 rsa 2048 \"двадцять один тридцять\" \"двадцять один тридцять\" \"test@example.org\" "--" "--" "--" "--" "i18n_ret_reqstatus" "i18n_ret_requestid""
	rlRun "pki -d $CERTDB_DIR \
		-c $CERTDB_DIR_PASSWORD \
		-n \"$CA_agentV_user\" \
		ca-cert-request-review $i18n_ret_requestid \
		--action approve 1> $TmpDir/i18n-pkcs10-approve-out" 0 "As $CA_agentV_user Approve Certificate Request"
	rlAssertGrep "Approved certificate request $i18n_ret_requestid" "$TmpDir/i18n-pkcs10-approve-out"
	rlRun "valid_i18n_pkcs10_serialNumber=\$(pki cert-request-show $i18n_ret_requestid | grep \"Certificate ID\" | sed 's/ //g' | cut -d: -f2)"
	rlRun "pki cert-show $valid_i18n_pkcs10_serialNumber 1> $temp_out" 0 "Executing pki cert-show $valid_i18n_valid_pkcs10_serialNumber"
	rlAssertGrep "двадцять один тридцять" "$temp_out"
	rlAssertGrep "двадцять один тридцять" "$temp_out"
	rlPhaseEnd 

	rlPhaseStartCleanup "pki cert-show cleanup: Delete temp dir"
	rlRun "popd"
	rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    	rlPhaseEnd
}
