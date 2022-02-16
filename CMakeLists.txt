cmake_minimum_required(VERSION 3.22)

project(particles-metal)

    add_subdirectory(deps)

    add_executable(particles-metal
        src/main.mm
        src/Particle.h
        src/Emitter.h
        src/Camera.h
        src/ui/imgui.h

        src/metal/shaders.metal
    )

    # TODO https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/platform_dependent_issues/HowToUseExistingOSXFrameworks
    target_link_libraries(particles-metal PRIVATE glfw glm Dear-ImGui "-framework Metal -framework QuartzCore")
    target_include_directories(particles-metal PRIVATE ${CMAKE_CURRENT_LIST_DIR}/src)

    # set_source_files_properties(src/main.cpp PROPERTIES COMPILE_FLAGS -xobjective-c++)
    # set_source_files_properties(src/main.cpp PROPERTIES LANGUAGE OBJCXX)
    set_source_files_properties(src/metal/shaders.metal PROPERTIES LANGUAGE METAL)
    set_target_properties(particles-metal
        PROPERTIES
            XCODE_ATTRIBUTE_MTL_HEADER_SEARCH_PATHS ${CMAKE_CURRENT_LIST_DIR}/src
            XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
    )

    target_compile_features(particles-metal PRIVATE cxx_std_17)
