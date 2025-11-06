# CF Compile Performance Test Bed

My harness for testing the parse/compile performance of all 3 CF engines (Lucee, Adobe CF, BoxLang)

To run this:

* clone the repo
* run `box install`
* Start each server `start server-compilePerfTest_BoxLang.json`, `start server-compilePerfTest_lucee.json`, etc
* hit the index page on each server

The test harness attempts to clear trusted cache and delete class files, but I don't really trust it.  When testing, I always restarted each server before each run to get a true test of cold parser performance with nothing cached or warmed up.  
