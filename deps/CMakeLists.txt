cmake_minimum_required(VERSION 3.22)

# glm
add_subdirectory(glm)

# imgui
add_library(Dear-ImGui STATIC
    imgui/imconfig.h
    imgui/imgui_demo.cpp
    imgui/imgui_draw.cpp
    imgui/imgui_internal.h
    imgui/imgui_tables.cpp
    imgui/imgui_widgets.cpp
    imgui/imgui.cpp
    imgui/imgui.h
    imgui/imstb_rectpack.h
    imgui/imstb_textedit.h
    imgui/imstb_truetype.h

    # backends
    # imgui/backends/imgui_impl_osx.h
    # imgui/backends/imgui_impl_osx.mm

    imgui/backends/imgui_impl_metal.h
    imgui/backends/imgui_impl_metal.mm
    )

target_include_directories(Dear-ImGui PUBLIC imgui imgui/backends)
target_link_libraries(Dear-ImGui PUBLIC "-framework GameController")

set_target_properties(Dear-ImGui
    PROPERTIES
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_WEAK YES
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
)

target_compile_features(Dear-ImGui PUBLIC cxx_std_17)
