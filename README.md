# InetTest
Print the list of all current TCP connections in iOS.


As Apple block the usage of ```sysctlbyname``` from iOS 9, this library only can be used on simulator, or under iOS 9.


Most of the code is copied from [StackoverflowTest](https://github.com/dcorbatta/StackoverflowTest), I did some changes to make it compliance with iOS simulator above iOS 9.
