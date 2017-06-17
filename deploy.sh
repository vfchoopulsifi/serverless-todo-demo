#!/usr/bin/env bash

export AWS_DEFAULT_REGION=eu-central-1
export AWS_REGION=eu-central-1

set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STACK_NAME=awsugs-todo

cd backend
npm install
npm test
npm install --prod
cd ..

aws cloudformation package --template-file cfn.yaml --s3-bucket ${ACCOUNT_ID}-sam-deploy-${AWS_REGION} --s3-prefix ${STACK_NAME} --output-template-file cfn.packaged.yaml

aws cloudformation deploy --template-file cfn.packaged.yaml --stack-name ${STACK_NAME} --capabilities CAPABILITY_IAM || echo "No Update"

cd frontend
rm -rf $(pwd)/dist
yarn install
bower install
gulp build
BUCKET=$(aws cloudformation describe-stack-resources --stack-name ${STACK_NAME} --logical-resource-id WebappBucket --query "StackResources[].PhysicalResourceId" --output text)
aws s3 sync --delete --exact-timestamps dist/ s3://${BUCKET}
aws s3 cp dist/index.html s3://${BUCKET}/index.html
cd ..

CFURL=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey == 'WebUrl'].OutputValue" --output text)
echo "Website is available under: ${CFURL}"