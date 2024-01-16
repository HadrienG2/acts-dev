#!/bin/bash

###################### ACTS DEVELOPMENT CONTAINER BUILDER ######################
# Run this script to regenerate the "acts-dev" docker image based on the       #
# latest developments of my acts repo. When short on time, you can also study  #
# it to run only the part that you're interested in.                           #
################################################################################

# Force bash to catch more errors
set -euo pipefail
IFS=$'\n\t'

# Build the base system
buildah build --layers                                                         \
              --squash                                                         \
              --format=docker                                                  \
              --tag acts-dev-base                                              \
              -f Dockerfile.base .
buildah rm -a
buildah rmi -p

# Run the actual Acts build
#
# This step cannot be made part of the Dockerfile above because it requires a
# bind mount of the Actd development source tree, and the Docker Build
# Reproducibilty Strike Force won't let us do such an unclean thing.
#
podman run -v ~/Bureau/Programmation/acts:/mnt/acts                            \
           --name acts-dev-cont                                                \
           acts-dev-base                                                       \
           bash /root/acts-build-worker.sh

# If the ACTS build succeeded, we can now commit the acts-dev image from the
# acts-dev-cont container that we just made...
podman commit --change "CMD bash" acts-dev-cont acts-dev

# ...and then we don't need that container anymore and can drop it
podman container rm acts-dev-cont

# Alright, we're done
echo "*** Acts development container was built successfully ***"

# NOTE: The output "acts-dev" image preserves the CMake build cache, so that
#       you can quickly re-run the build by just firing up a container in
#       acts-dev with the same bind mount as above, go to /mnt/acts/spack-build,
#       and run "ninja" and whatever else you'd like in there.
