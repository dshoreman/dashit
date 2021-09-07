welcome_screen() {
    echo
    echo "Welcome to Dashit!"

    print_system_info
}

print_system_info() {
    local CPU_ARCH CPU_MODEL CPU_TYPE

    process_system_info
    echo
    echo "Current System: ${CPU_TYPE} (${CPU_ARCH})"
    echo "${CPU_MODEL}"
}

process_system_info() {
    CPU_ARCH="$(lscpu | grep 'Architecture' | cut -d':' -f2)"
    CPU_TYPE="$(lscpu | grep 'Vendor ID' | cut -d':' -f2)"
    CPU_MODEL="$(lscpu | grep 'Model name' | cut -d':' -f2)"
}
