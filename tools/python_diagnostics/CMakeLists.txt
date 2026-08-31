cmake_minimum_required(VERSION 3.20)
project(scoutr_python_launcher LANGUAGES CXX)

add_executable(scoutr_python_launcher launcher.cpp)
target_compile_features(scoutr_python_launcher PRIVATE cxx_std_17)
