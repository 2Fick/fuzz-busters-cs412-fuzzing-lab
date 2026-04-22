# **CS-412 Software Security \- Fuzzing Lab**

This repository contains the reproducible fuzzing environment for the CS-412 Fuzzing Lab at EPFL (Spring 2026).

## **Project Structure**

Following the requirements in Section 5 of the lab manual, the repository is structured as follows:

```
fuzz-busters-cs412-fuzzing-lab/  
├── Dockerfile               \# Container definition for AFL++ environment  
├── Makefile                 \# Build system for campaigns and reporting  
├── report.tex               \# LaTeX source for the USENIX-style report  
├── report.pdf               \# Final compiled report (max 4 pages \+ appendix)  
├── src/  
│   ├── harness.c            \# Primary fuzzing harness source code  
│   └── harness\_persistent.c \# Persistent-mode variant for performance tests (Q8)  
├── patches/                 \# Library patches (e.g., CRC/checksum removal)  
├── seeds/                   \# Initial seed corpus for the fuzzer  
├── dictionaries/            \# Format-specific dictionaries (e.g., png.dict)  
├── findings/                \# Results from instrumented (white-box) campaign  
│   └── default/  
│       └── plot\_data        \# Data used for generating coverage graphs  
├── findings-qemu/           \# Results from QEMU-mode (black-box) campaign  
│   └── default/  
│       └── plot\_data        \# Data used for generating QEMU coverage graphs  
├── plot\_output/             \# afl-plot output for instrumented campaign  
│   ├── index.html  
│   ├── edges.png            \# Coverage graph (Required for Appendix)  
│   └── exec\_speed.png       \# Execution speed graph  
└── plot\_output\_qemu/        \# afl-plot output for QEMU campaign  
    ├── index.html  
    └── edges.png            \# Coverage graph (Required for Appendix)
```

## **Prerequisites**

* **Docker** or **Podman**: Required to run the reproducible fuzzing environment.  
* **LaTeX Environment**: (e.g., TeX Live or Overleaf) for compiling report.tex.

## **Quick Start**

### **1\. Build the Environment**

Building the Docker container ensures a reproducible environment with the AFL++ toolchain and all necessary library dependencies.

```
make build-docker
```

### **2\. Launch the Instrumented Campaign (White-box)**

This target compiles the library with afl-clang-fast and AddressSanitizer (ASan) enabled, then starts the fuzzer.

```
make fuzz
```

### **3\. Launch the QEMU Campaign (Black-box)**

This target compiles the library with standard gcc (no instrumentation) and launches AFL++ in QEMU emulation mode.

```
make fuzz-qemu
```

### **4\. Generate Reports and Plots**

After running the campaigns for at least 30 minutes, generate the visual progress plots required for the report:

```
make plot
```

### **5\. Clean Artifacts**

To reset the environment and remove findings:

```
make clean
```

## **Authors**

* **Sylvain Pichot**  
* **Jeanne De Marmiés**  
* **Erik Hübner**  
* **Youcef Amar**

## **References**

* [AFL++ Documentation](https://aflplus.plus/docs/)  
* [USENIX LaTeX Templates](https://www.usenix.org/conferences/author-resources/paper-templates)
