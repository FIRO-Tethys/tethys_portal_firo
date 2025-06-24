#!/usr/bin/env bash
apptainer build --fakeroot --fix-perms ../firo-portal-singularity_latest.sif firo_portal2.def
