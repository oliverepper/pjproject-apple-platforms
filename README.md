# pjproject-apple-platforms

Script to build and install a xcframework that has headers and static libraries for all Apple platforms to be used in Xcode for development against pjproject.

## How to use
Before running you can customize the pjsip version used, modifying `PJSIP_VERSION` constant on `start.sh`

Then you can run the script:

```sh
sh start.sh
```

> Disclaimer: Right now the xcframework is just generated correctly if the script is executed from an apple silicon mac.

