#-----------------------------------------------------------
# Master cmake lists file
# Implements the ACC build system.  Called by boilerplate
# text:
#      include($ENV{ACC_BUILD_SYSTEM}/Master.cmake)
# found in CMakeLists.txt files in project directories.
#-----------------------------------------------------------
cmake_minimum_required(VERSION 2.8)
#-----------------------------------------------------------
# Set link_directories relative path composition to use new
# behvaior that appends relative path information to the
# CMAKE_CURRENT_SOURCE_DIR value.
#-----------------------------------------------------------
cmake_policy(SET CMP0015 NEW)

#-------------------------------------------------------
# Import environment variables that influence the build
#-------------------------------------------------------
set(RELEASE_NAME $ENV{ACC_RELEASE})
set(RELEASE_NAME_TRUE $ENV{ACC_TRUE_RELEASE})
set(RELEASE_DIR $ENV{ACC_RELEASE_DIR})

set(RELEASE_LIB ${RELEASE_DIR}/lib)
set(PACKAGES_DIR ${RELEASE_DIR}/packages)


#-------------------------------------------------------
# Check to see if shared object creation is enabled.
# If enabled, shared object libraries will only be
# created for projects that define 
#   CREATE_SHARED
# in their CmakeLists.txt file.
#
# TWO variables need to be set to produce a shared
# object library for a given project.
#  Shell: ACC_ENABLE_SHARED
#  Cmake: CREATE_SHARED
#-------------------------------------------------------
set(ENABLE_SHARED $ENV{ACC_ENABLE_SHARED})


IF (${LIBNAME})
	project(${LIBNAME})
ENDIF ()


#   Compiler flags
#-----------------------------------
# Platform-dependent flag sets here.
# Compiler-dependent also?
set (CMAKE_C_FLAGS "-Df2cFortran -O2 -std=gnu99 -mcmodel=medium -DCESR_F90_DOUBLE -DCESR_DOUBLE -Wall -DCESR_LINUX -D_POSIX -D_REENTRANT -Wall -fPIC -Wno-trigraphs -Wno-unused")
set (CMAKE_C_FLAGS_DEBUG "-g -Df2cFortran -O2 -std=gnu99 -mcmodel=medium -DCESR_F90_DOUBLE -DCESR_DOUBLE -Wall -DCESR_LINUX -D_POSIX -D_REENTRANT -Wall -fPIC -Wno-trigraphs -Wno-unused")

set (CMAKE_Fortran_COMPILER ifort)
enable_language( Fortran )
set (CMAKE_Fortran_FLAGS "-Df2cFortran -DCESR_F90_DOUBLE -DCESR_DOUBLE -DCESR_UNIX -DCESR_LINUX -fpp -u -traceback -mcmodel=medium")
set (CMAKE_Fortran_FLAGS_DEBUG "-g -Df2cFortran -DCESR_F90_DOUBLE -DCESR_DOUBLE -DCESR_UNIX -DCESR_LINUX -fpp -u -traceback -mcmodel=medium")


set(CMAKE_EXE_LINKER_FLAGS "-lreadline -lpthread -lstdc++ -lX11")


IF (CMAKE_BUILD_TYPE MATCHES "[Dd][Ee][Bb][Uu][Gg]")
  SET(DEBUG 1)
ELSE ()
  SET(DEBUG 0)
ENDIF ()


IF ($ENV{ACC_BUILD_EXES})
  SET(BUILD_EXES 1)
ELSE ()
  SET(BUILD_EXES 0)
ENDIF ()



# Print some friendly build information
#-----------------------------------------
message("")
IF (DEBUG)
  message("Build type           : Debug")
ELSE ()
  message("Build type           : Production")
ENDIF ()
message("Linking with release : ${RELEASE_NAME} \(${RELEASE_NAME_TRUE}\)\n")



#   Path definitions
#-----------------------------------
IF (DEBUG)
  set (OUTPUT_BASEDIR ${CMAKE_SOURCE_DIR}/../debug)
ELSE ()
  set (OUTPUT_BASEDIR ${CMAKE_SOURCE_DIR}/../production)
ENDIF ()

set (LIBRARY_OUTPUT_PATH ${OUTPUT_BASEDIR}/lib)
set (EXECUTABLE_OUTPUT_PATH ${OUTPUT_BASEDIR}/bin)
set (CMAKE_Fortran_MODULE_DIRECTORY ${OUTPUT_BASEDIR}/modules)


#   System library locators
#-----------------------------------
find_package(X11)



#   Include directories
#-------------------------
# TODO: Double each include directory entry to search for a local (../<xxx>) path and THEN
#       to a release-based path?
#
#  This leaves the possibility that someone may delete the local library, and initiate a build
#    that requires that library while leaving the local souce tree and include files intact.
#  This new build will then perform the divergent action of linking against the release library
# but extracting constants and other header information from the LOCAL source tree.  
#
#   This is bad, no?  This is how the present build system is set up to operate as well?
#
SET (MASTER_INC_DIRS
  ${X11_INCLUDE_DIR}
  ${PACKAGES_DIR}/include
  ${PACKAGES_DIR}/forest/include
  ${PACKAGES_DIR}/recipes_c-ansi/include
  ${PACKAGES_DIR}/cfortran/include
  ${PACKAGES_DIR}/root/include
  ${PACKAGES_DIR}/modules
  ${ROOT_INC}
  ${RELEASE_DIR}/modules
)
  

# Add local include paths to search list if they exist
#------------------------------------------------------
foreach(dir ${INC_DIRS})
  STRING(FIND ${dir} "../" relative)
  STRING(REPLACE "../" "" dirnew ${dir})
  IF (${relative} EQUAL 0)
    LIST(APPEND MASTER_INC_DIRS ${dir})
    LIST(APPEND MASTER_INC_DIRS ${RELEASE_DIR}/${dirnew})
  ELSE ()
    LIST(APPEND MASTER_INC_DIRS ${dir})
  ENDIF ()
endforeach(dir)
LIST(REMOVE_DUPLICATES MASTER_INC_DIRS)
INCLUDE_DIRECTORIES(${MASTER_INC_DIRS})


#  Link directories - order matters
# Lowest level to highest, i.e. in
# order of increasing abstraction.
#-----------------------------------
SET(MASTER_LINK_DIRS
  /lib64
  /usr/lib64
  ${PACKAGES_DIR}/lib
  ${PACKAGES_DIR}/root/lib
  ${OUTPUT_BASEDIR}/lib
  ${RELEASE_DIR}/lib
)
LINK_DIRECTORIES(${MASTER_LINK_DIRS})



# Collect list of all source files for all supported languages
# from all directories mentioned in project CMakeLists.txt file.
#----------------------------------------------------------------
foreach(dir ${SRC_DIRS})
    file(GLOB temp_contents ${dir}/*.c)
    LIST(APPEND sources ${temp_contents})

    file(GLOB temp_contents ${dir}/*.cpp)
    LIST(APPEND sources ${temp_contents})

    file(GLOB temp_contents ${dir}/*.cc)
    LIST(APPEND sources ${temp_contents})

    file(GLOB temp_contents ${dir}/*.cxx)
    LIST(APPEND sources ${temp_contents})

    file(GLOB temp_contents ${dir}/*.f)
    LIST(APPEND sources ${temp_contents})

    file(GLOB temp_contents ${dir}/*.F)
    LIST(APPEND sources ${temp_contents})

    file(GLOB temp_contents ${dir}/*.f90)
    LIST(APPEND sources ${temp_contents})
endforeach(dir)


set( LAB_LIBS
  c_utils
  recipes_f-90_LEPP
  sim_utils
  mpmnet
  cbi_net
  cbpmfio
  BeamInstSupport
  CBPM-TSHARC
  CBIC
  bmad
  cesr_utils
  mpm_utils
  nonlin_bpm
  tao
  tao_cesr
  CesrBPM
  bmadz
  cesrv
  bsim
  bsim_cesr
  genplt
  displays
  XbsmAnalysis
)

set(DEPS )


IF (${LIBNAME})
  foreach( lablib ${LAB_LIBS})
    IF( ${LIBNAME} STREQUAL ${lablib} )
    ELSE ()
      LIST(APPEND DEPS ${lablib})
    ENDIF ()
  endforeach()
ENDIF ()
  
##message("DEPS=${DEPS}")


#----------------------------------------------------------------
# If any pre-build script is specified, run it before building
# any code.  The pre-build script may generate code or header
# files.
#----------------------------------------------------------------
IF (PREBUILD_ACTION)
  message("Executing pre-build action...")
  EXECUTE_PROCESS (COMMAND ${PREBUILD_ACTION})
ENDIF ()

set(TARGETS)

IF (LIBNAME)
  add_library( ${LIBNAME} STATIC ${sources} )
  LIST(APPEND TARGETS ${LIBNAME})
  SET_TARGET_PROPERTIES(${LIBNAME} PROPERTIES OUTPUT_NAME ${LIBNAME})
  TARGET_LINK_LIBRARIES(${LIBNAME} ${DEPS})
ENDIF ()


#----------------------------------------------------------------
# Copy the contents of a config directory to 
# <DIR>/../config/${LIBNAME} if one exists.
#----------------------------------------------------------------
IF (IS_DIRECTORY "../config")
  message("Copying config directory contents to ${CMAKE_SOURCE_DIR}/../config/${LIBNAME}...")
  file (MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/../config")
  EXECUTE_PROCESS (COMMAND cp -rfu ${CMAKE_SOURCE_DIR}/config ${CMAKE_SOURCE_DIR}/../config/${LIBNAME})
ENDIF ()




#----------------------------------------------------------------
# For selectively producing shared object libraries (.so files).
#
# Shell variable ACC_ENABLE_SHARED needs to be set to 
#  "Y" or "true" or "1"
#    - AND - 
# set (CREATE_SHARED true) needs to be present in the individual
#  project's CMakeLists.txt file.
#----------------------------------------------------------------
IF (ENABLE_SHARED AND CREATE_SHARED)
  add_library (${LIBNAME}-shared SHARED ${sources})
  LIST(APPEND TARGETS ${LIBNAME}-shared)
  SET_TARGET_PROPERTIES (${LIBNAME}-shared PROPERTIES OUTPUT_NAME ${LIBNAME})
  TARGET_LINK_LIBRARIES (${LIBNAME}-shared ${DEPS})
ENDIF ()






#---------------------------------------------------------------
# Process each EXE build description file mentioned in the
# project's CMakeLists.txt file.
#---------------------------------------------------------------
foreach(exespec ${EXE_SPECS})

    include(${exespec})


  # TODO: Convert this to macro or function
  foreach(dir ${INC_DIRS})
    STRING(FIND ${dir} "../" relative)
    STRING(REPLACE "../" "" dirnew ${dir})
    IF (${relative} EQUAL 0)
      LIST(APPEND MASTER_INC_DIRS ${dir})
      LIST(APPEND MASTER_INC_DIRS ${RELEASE_DIR}/${dirnew})
    ELSE ()
      LIST(APPEND MASTER_INC_DIRS ${dir})
    ENDIF ()
  endforeach(dir)
  LIST(REMOVE_DUPLICATES MASTER_INC_DIRS)
  INCLUDE_DIRECTORIES(${MASTER_INC_DIRS})



  set(DEPS ${LINK_LIBS})

  #----------------------------------------------------------------
  # Make this project's EXE build depend upon the product of each
  # build that is listed as a dependency.  If those build
  # products are newer than this project's EXE, relink this
  # project's EXE.  Only invoke add_library to tie in external
  # dependencies a single time for each unique target.
  #----------------------------------------------------------------
  foreach(dep ${DEPS})

    IF(NOT ${LIBNAME} MATCHES ${dep})
      LIST(FIND TARGETS ${dep} DEP_SEEN)
      IF(NOT ${DEP_SEEN} EQUAL -1)
        IF (EXISTS ${OUTPUT_BASEDIR}/lib/lib${dep}.a)
          message("Found ${dep} in ${OUTPUT_BASEDIR}/lib/")
          add_library(${dep} STATIC IMPORTED)
          LIST(APPEND TARGETS ${dep})
          set_property(TARGET ${dep} PROPERTY IMPORTED_LOCATION ${OUTPUT_BASEDIR}/lib/lib${dep}.a)
        ELSEIF (EXISTS ${PACKAGES_DIR}/lib/lib${dep}.a)
          message("Found ${dep} in ${PACKAGES_DIR}/lib/")
          add_library(${dep} STATIC IMPORTED)
          LIST(APPEND TARGETS ${dep})
          set_property(TARGET ${dep} PROPERTY IMPORTED_LOCATION ${PACKAGES_DIR}/lib/lib${dep}.a)
        ELSEIF (EXISTS ${RELEASE_DIR}/lib/lib${dep}.a)
          message("Found ${dep} in ${RELEASE_DIR}/lib/")
          add_library(${dep} STATIC IMPORTED)
          LIST(APPEND TARGETS ${dep})
          set_property(TARGET ${dep} PROPERTY IMPORTED_LOCATION ${RELEASE_DIR}/lib/lib${dep}.a)
        ENDIF ()
      ENDIF()
    ENDIF()


  endforeach(dep)


      file(GLOB temp_contents ${dir}/*.cc)
      LIST(APPEND SRC_FILES ${temp_contents})
 
      file(GLOB temp_contents ${dir}/*.cxx)
      LIST(APPEND SRC_FILES ${temp_contents})

      file(GLOB temp_contents ${dir}/*.f)
      LIST(APPEND SRC_FILES ${temp_contents})

      file(GLOB temp_contents ${dir}/*.F)
      LIST(APPEND SRC_FILES ${temp_contents})

      file(GLOB temp_contents ${dir}/*.f90)
      LIST(APPEND SRC_FILES ${temp_contents})
  endforeach(dir)
  
  include($ENV{ACC_BUILD_SYSTEM}/exe.cmake)


endforeach(exespec)
