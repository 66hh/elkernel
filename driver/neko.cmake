# search the source codes
set(_NEKO_SRC "")
set(_SEARCH_FILES "")
  file(GLOB_RECURSE _SEARCH_FILES ${ELKERNEL_DRIVER_DIR}/*.e)
  list(APPEND _NEKO_SRC ${_SEARCH_FILES})

# batch compiling
set(CUSTOM_IMM_PATH ${ELKERNEL_BUILD_DIR}/CMakeFiles/driver.dir)
  foreach(_SRC IN LISTS _NEKO_SRC)
    get_filename_component(_FILE ${_SRC} NAME_WE)
    get_filename_component(_FILE_E ${_SRC} NAME)
    get_filename_component(_FILE_DIR ${_SRC} DIRECTORY)
    file(RELATIVE_PATH _FILE_OF_ROOT ${ELKERNEL_ROOT_DIR} ${_SRC})
    file(RELATIVE_PATH _FILE_OF_DRIVER ${ELKERNEL_DRIVER_DIR} ${_SRC})
    file(MAKE_DIRECTORY ${CUSTOM_IMM_PATH}/${_FILE_OF_DRIVER})
    set(_NEKO_IMM ${CUSTOM_IMM_PATH}/${_FILE_OF_DRIVER}/${_FILE_E}.o)

    add_custom_target(${_FILE} ALL

      COMMENT "Docker pulling ghcr.io/thesnowfield/el-buildtool:latest"
      COMMAND docker pull ghcr.io/thesnowfield/el-buildtool:latest
    
      COMMENT "Building ${_FILE_OF_ROOT} use el-buildtool"
      COMMAND docker run
        -e INPUT_FILE=workspace/${_FILE_OF_ROOT}
        -e INPUT_OPT_FAST_ARRAY=\"true\"
        -e INPUT_OPT_STACK_CHECK=\"false\"
        -e INPUT_OPT_DEADLOOP_CHECK=\"false\"
        -v \"${ELKERNEL_ROOT_DIR}:/workspace\"
        ghcr.io/thesnowfield/el-buildtool:latest
    
      COMMAND mv -f
        ${_FILE_DIR}/${_FILE}.obj
        ${CUSTOM_IMM_PATH}/${_FILE_OF_DRIVER}/${_FILE}.obj
    )

    add_custom_command(TARGET ${_FILE} POST_BUILD
      COMMENT "[ ** ] Patching symbol '_neko_load@0'"
      COMMAND python3 ${ELKERNEL_TOOL_DIR}/patch-symbol.py
        _neko_load@0:_neko_load
        ${CUSTOM_IMM_PATH}/${_FILE_OF_DRIVER}/${_FILE}.obj ${_NEKO_IMM}
    )

    add_custom_command(TARGET ${_FILE} POST_BUILD
      COMMENT "[ ** ] Patching symbol '_neko_unload@0'"
      COMMAND python3 ${ELKERNEL_TOOL_DIR}/patch-symbol.py
      _neko_unload@0:_neko_unload
        ${_NEKO_IMM} ${_NEKO_IMM}
    )

    add_custom_command(TARGET ${_FILE} POST_BUILD
      COMMENT "[ ** ] Patching symbol '_neko_on_event@0'"
      COMMAND python3 ${ELKERNEL_TOOL_DIR}/patch-symbol.py
        _neko_on_event@0:_neko_on_event
        ${_NEKO_IMM} ${_NEKO_IMM}
    )

    add_custom_command(TARGET ${_FILE} POST_BUILD
      COMMENT "[ ** ] Patching symbol '_krnl_ProcessNotifyLib@12'"
      COMMAND python3 ${ELKERNEL_TOOL_DIR}/patch-symbol.py
        _krnl_ProcessNotifyLib@12:_krnl_ProcessNotifyLib
        ${_NEKO_IMM} ${_NEKO_IMM}
    )

    add_custom_command(TARGET ${_FILE} POST_BUILD
      COMMENT "[ ** ] Linking '${_FILE_OF_ROOT}'"
      COMMAND ld -melf_i386 -shared
        -o ${CUSTOM_IMM_PATH}/${_FILE_OF_DRIVER}/${_FILE}.neko ${_NEKO_IMM}
        -L${ELKERNEL_BUILD_DIR} -lnekostub
    )

  endforeach()
