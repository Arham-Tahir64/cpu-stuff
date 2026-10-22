cmake_minimum_required(VERSION 3.20)
project(cpu_stuff_host_probe C)
add_executable(host_probe main.c)
target_compile_options(host_probe PRIVATE -Wall -Wextra -Werror)
