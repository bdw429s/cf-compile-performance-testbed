# CF Compile Performance Test Bed

My harness for testing the parse/compile performance of all 3 CF engines (Lucee, Adobe CF, BoxLang)

To run this:

* clone the repo
* run `box install`
* Start each server `start server-compilePerfTest_BoxLang.json`, `start server-compilePerfTest_lucee.json`, etc
* hit the index page on each server

The test harness attempts to clear trusted cache and delete class files, but I don't really trust it.  When testing, I always restarted each server before each run to get a true test of cold parser performance with nothing cached or warmed up.  

Your results will likely be influenced by the speed of your hard drive and the number of CPU cores you have.  

When comparing BoxLang and Lucee, use the following line under the BoxLang setup.
```js
// use this one when comparing to Lucee  (parse/compile only)
compiler = compilerBoxLang;
```

When comparing BoxLang and Adobe CF, use the following line under the BoxLang setup.
```js
// Use this one when comparing to Adobe (parse/compile + instanatiation)
compiler = compilerManualInclude;
```

This is to provide an apples-to-apples test since Adobe CF and Lucee don't have the same capabilities when it comes to JUST parsing and compiling vs actually instantiating CFCs.