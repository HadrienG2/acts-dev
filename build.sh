#!/bin/bash

###################### ACTS DEVELOPMENT CONTAINER BUILDER ######################
# Run this script to regenerate the "acts-dev" docker image based on the       #
# latest developments of my acts-core repo. When short on time, you can also   #
# study it to run only the part that you're interested in.                     #
################################################################################

# Force bash to catch more errors
set -euo pipefail
IFS=$'\n\t'

# Build the base system
docker build --pull --tag acts-dev-base -f Dockerfile.base .

# Run the actual Acts build
#
# This step cannot be made part of the Dockerfile above because it requires a
# bind mount of the Actd development source tree, and the Docker Build
# Reproducibilty Strike Force won't let us do such an unclean thing.
#
docker run -v ~/Bureau/IJCLab/Programmation/acts-core:/mnt/acts-core:ro        \
           --name acts-dev-cont                                                \
           acts-dev-base                                                       \
           bash /root/acts-build/acts-build-worker.sh

# If the ACTS build succeeded, we can now commit the acts-dev image from the
# acts-dev-cont container that we just made...
docker commit --change "CMD bash" acts-dev-cont acts-dev

# ...and then we don't need that container anymore and can drop it
docker container rm acts-dev-cont

# Alright, we're done
echo "*** Acts development container was built successfully ***"

# NOTE: The output "acts-dev" image preserves the CMake build cache, so that
#       you can quickly re-run the build by just firing up a container in
#       acts-dev with the same bind mount as above, go to /root/acts-build,
#       and run "ninja" and whatever else you'd like in there.
