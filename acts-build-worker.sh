####################### CONTAINER-SIDE ACTS BUILD SCRIPT #######################
# This script is meant to run inside of the container. If you are trying to    #
# build the container, you're probably looking for the "build.sh" script.      #
################################################################################

# Force bash to catch more errors
set -euo pipefail
# NOTE: Don't exclude spaces from IFS as spack spec need it

# Flush remains of any previous build
rm -rf spack-*

# Run a spack build of Acts
#
# FIXME: Set back to unlimited concurrency once it doesn't OOM anymore
#
spack dev-build -j3 --until build ${ACTS_SPACK_SPEC}
ACTS_BUILD_DIR_NAME=`ls | grep -E "^spack-build[^.]*$"`
ACTS_BUILD_DIR=/mnt/acts/${ACTS_BUILD_DIR_NAME}
cd ${ACTS_BUILD_DIR}

# We're done with Spack ops, so we can perma-source the acts build environment
# since that's what the user of this Acts development image will always want.
source ~/acts-build-env.sh
echo "source ~/acts-build-env.sh" >> ${SETUP_ENV}

# FIXME: Must disable bits of Spack's python environment, as that interacts
#        badly with the system python installation and prevents using gdb.
echo "unset PYTHONHOME" >> ${SETUP_ENV}
echo "unset PYTHONPATH" >> ${SETUP_ENV}

# Run the unit tests
ctest -j8
echo "==============="

# Run the integration tests as well
cmake --build . -- integrationtests
echo "==============="

# Run the benchmarks as well
cd bin
./ActsBenchmarkAnnulusBoundsBenchmark
echo "---------------"
./ActsBenchmarkAtlasStepper
echo "---------------"
./ActsBenchmarkBoundaryCheck
echo "---------------"
./ActsBenchmarkEigenStepper
echo "---------------"
./ActsBenchmarkRayFrustumBenchmark
echo "---------------"
./ActsBenchmarkSolenoidField
echo "---------------"
./ActsBenchmarkSurfaceIntersection
echo "==============="

# Run the examples (skip some in Debug builds, as they are too slow)
#
# FIXME: Cannot test ActsExampleEventRecording,
#        ActsExampleGeantinoRecordingGdml, ActsExampleMagneticField,
#        ActsExampleMagneticFieldAccess, ActsExampleMaterialMappingDD4hep,
#        ActsExampleMaterialMappingGeneric, ActsExampleReadCsvGeneric,
#        ActsExampleCKFTracksDD4hep, ActsExampleTruthTracksDD4hep,
#        ActsExampleCKFTracksGeneric, ActsExampleTruthTracksGeneric and
#        ActsExampleVertexFinderReader as no input data file
#        is provided and it's unclear how to get one.
#
# FIXME: Cannot auto-test ActsExampleAdaptiveMultiVertexFinder,
#        ActsExampleFatrasAligned, ActsExampleFatrasDD4hep,
#        ActsExampleFatrasGeneric, ActsExampleFatrasTGeo,
#        ActsExampleGeometryTGeo, ActsExampleHepMC3,
#        ActsExampleMaterialMappingTGeo, ActsExampleMaterialValidationTGeo,
#        ActsExamplePropagationTGeo and ActsExampleVertexFitter as they do not
#        reliably exit a nonzero status code upon major failure (e.g. input not
#        found).
#
# FIXME: The PayloadDetector-based examples ActsExamplePropagationPayload and
#        ActsExampleFatrasPayload crash with a bad_any_cast, see
#        https://github.com/acts-project/acts/issues/164 .
#
# FIXME: ActsExampleGeantinoRecording must currently be forced into
#        single-threaded, see https://github.com/acts-project/acts/issues/207 .
#
# FIXME: ActsExampleIterativeVertexFinder and ActsExamplePropagationEmpty fail
#        for unknown reasons, reaching an infinite step count.
#
# TODO: Add seeding examples
#
DD4HEP_PREFIX=`spack location --install-dir dd4hep`
DD4HEP_ENV_SCRIPT="${DD4HEP_PREFIX}/bin/thisdd4hep.sh"
set +u && source ${DD4HEP_ENV_SCRIPT} && set -u
echo "source ${DD4HEP_ENV_SCRIPT}" > ${SETUP_ENV}
cd /mnt/acts/Examples
run_example () { ${ACTS_BUILD_DIR}/bin/$* -n 100; }
run_example ActsExampleGeantinoRecordingDD4hep -j1
echo "---------------"
run_example ActsExampleGeometryAligned
echo "---------------"
run_example ActsExampleGeometryDD4hep
echo "---------------"
run_example ActsExampleGeometryEmpty
echo "---------------"
run_example ActsExampleGeometryGeneric
echo "---------------"
run_example ActsExampleGeometryPayload
echo "---------------"
run_example ActsExampleHelloWorld
echo "---------------"
run_example ActsExampleMaterialValidationDD4hep
echo "---------------"
run_example ActsExampleMaterialValidationGeneric
echo "---------------"
run_example ActsExampleParticleGun
echo "---------------"
run_example ActsExamplePropagationAligned
echo "---------------"
run_example ActsExamplePropagationDD4hep
echo "---------------"
run_example ActsExamplePropagationGeneric
echo "---------------"
run_example ActsExamplePythia8
echo "---------------"
run_example ActsTutorialVertexFinder
echo "==============="

# Try to keep docker image size down by dropping build stages, downloads, etc
#
# Note that you should _not_ run `spack gc` here as that would drop spack
# packages which are necessary for Acts to build, but not to run. Which is not
# what we want, we want a working Acts build environment here !
#
spack clean -a
