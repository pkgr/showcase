# Showcase

This repo hosts tests that make sure that applications present in the PKGR [showcase](https://pkgr.io/showcase) are working properly, on all target distributions.

## How it works

It launches micro EC2 instances, and can run expectations on SSH commands, and/or by launching a real browser to make sure the application is working.

Installation recipes can be found in the `data/` folder.

## Usage

    bundle install
    bundle exec rspec spec/
    # or
    bundle exec rspec spec/ -e "specific example name"

## Tested applications

* Gitlab - <https://pkgr.io/apps/pkgr/gitlabhq>

## TODO

* Parallelize tests.
