#!/bin/bash

find incoming/ -type f -name '*.deb' | while read fullpath; do
        pkg=(${fullpath//\// })
        component=${pkg[1]}
        file=${pkg[2]}

        find debcore -type f -name $file | grep $file >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then 
                echo $file
                [[ -d archive/$component ]] || mkdir -p archive/$component
                mv -v $fullpath archive/$component/
        fi
done
