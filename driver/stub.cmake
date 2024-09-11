project(nekostub)
add_compile_options(-m32)
add_link_options(-m32)

set(_SRC ${ELKERNEL_DRIVER_DIR}/stub.s)
set_property(SOURCE ${_SRC} PROPERTY LANGUAGE C)

# add source files
add_library(${PROJECT_NAME} SHARED
  ${ELKERNEL_DRIVER_DIR}/stub.s
)
