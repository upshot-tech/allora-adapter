# SPDX-License-Identifier: AGPL-3.0

# if any command fails then immediately exit
set -o errexit

# setup
rm -rf coverage
mkdir -p coverage

# create coverage report
forge coverage --report summary --report lcov 

lcov --remove lcov.info 'script/**' 'src/examples/**' -o lcov.info

# create html viewable coverage report
genhtml lcov.info --dark-mode -o coverage

# cleanup
rm -f coverage/lcov.info
mv lcov.info coverage

echo 'Success! Coverage data viewable in coverage/index.html'