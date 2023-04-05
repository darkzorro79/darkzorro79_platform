#!/bin/bash
helm repo add templating https://harbor.84.201.150.236.nip.io/chartrepo/library

helm push frontend-0.1.0.tgz oci://harbor.84.201.150.236.nip.io//library
