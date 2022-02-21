cmake_minimum_required(VERSION 3.22)

set(CMAKE_Swift_LANGUAGE_VERSION 5.3)

project(particles-metal LANGUAGES Swift OBJCXX CXX)

    add_subdirectory(deps)

    add_executable(particles-metal MACOSX_BUNDLE
        src/ui/Main.swift
        src/ui/ContentView.swift
        src/ui/AppDelegate.swift
        src/ui/Coordinator.swift

        $<IF:$<PLATFORM_ID:iOS>,
                src/ui/MetalView-iOS.swift
                src/ui/MetalWindow-iOS.swift
            , #else
                src/ui/MetalView-macOS.swift
                src/ui/MetalWindow-macOS.swift
        >

        src/ui/RendererWrapper.h
        src/ui/RendererWrapper.mm
        src/Renderer.h
        src/Renderer.mm

        src/metal/shaders.metal

        src/Particle.h
        src/Emitter.h
        src/Camera.h

        src/ui/imgui.h
    )

    target_compile_features(particles-metal PRIVATE cxx_std_17)
    target_include_directories(particles-metal PRIVATE src)
    target_link_libraries(particles-metal PRIVATE glm Dear-ImGui "-framework MetalPerformanceShaders")
    set_source_files_properties(src/metal/shaders.metal PROPERTIES LANGUAGE METAL)

    set_target_properties(particles-metal
        PROPERTIES
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_WEAK YES
        XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER src/ui/RendererWrapper.h
        XCODE_ATTRIBUTE_ENABLE_PREVIEWS YES # also set optimization level to -Onone
        XCODE_ATTRIBUTE_INFOPLIST_FILE ""
        XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE YES
        XCODE_ATTRIBUTE_INFOPLIST_KEY_UILaunchScreen_Generation YES
        XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION "alpha"
        XCODE_ATTRIBUTE_MARKETING_VERSION "alpha"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "Particles.Metal"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
        XCODE_ATTRIBUTE_MTL_HEADER_SEARCH_PATHS ${CMAKE_CURRENT_LIST_DIR}/src
    )
