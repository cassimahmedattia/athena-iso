for f in $(find $HOME/Athena-Out -name '*.iso*'); do
    gh release upload v23.06.23 $f
done
