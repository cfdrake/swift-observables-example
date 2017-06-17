/*:
# An Observable Pattern Implementation in Swift

By Colin Drake

## The Problem
Over the past few days, I've been working a new Mac app in Swift as a part of [Gumroad's Small Product Lab](https://gumroad.com/smallproductlab) challenge. This app contains a simple `struct` type, `AppConfig`, representing the application's editable configuration. What I needed to build was a view controller for the user to edit and update said values, and this is where I ran into trouble.

The normal pattern in the Objective-C world to implement this is to use [Cocoa Bindings](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CocoaBindings/CocoaBindings.html), an awesome feature implemented on top of [KVO](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) that allows you to automatically bind your (Mac) UI to instance variables in Interface Builder.

However, Cocoa Bindings will only work for types that are [subclasses of NSObject](http://stackoverflow.com/q/24092285). I felt that porting my `AppConfig` struct over to a class, let alone an `NSObject` subclass, conflicted with the fact that it was better represented as a [value type](https://www.mikeash.com/pyblog/friday-qa-2015-07-17-when-to-use-swift-structs-and-classes.html), and I definitely didn't want to needlessly bring in the Objective-C runtime for this simple case.

Given that I've been working on this app to both scratch an itch and to use Swift in a practical setting, I decided to write my own native Swift implementation of the [Observable Pattern](https://en.wikipedia.org/wiki/Observer_pattern).

## Protocols Everywhere
To begin with, I wanted to come up with a `protocol` that I could implement to satisfy my data binding woes. I decided on a `subscribe`/`unsubscribe` type model, passing in an owner/observer as the object to update a subscription off of.
*/
protocol ObservableProtocol {
    associatedtype T
    var value: T { get set }
    func subscribe(observer: AnyObject, block: @escaping (_ newValue: T, _ oldValue: T) -> ())
    func unsubscribe(observer: AnyObject)
}

/*:
## Implementation
Given that the `Observable` object has state/a lifecycle, I decided to make it a class:
*/
public final class Observable<T>: ObservableProtocol {
/*:
We'll start out by defining a variable and a couple of handy types.

Our model of subscribers is `observers`, a variable array of `ObserversEntry` entries. Each  entry is a tuple composed of a listening object and the block it expects to run upon the `Observable` firing. By passing in this listening object and associating it with the block to execute, we can easily look for it in the `unsubscribe` method to remove it.
*/
    typealias ObserverBlock = (_ newValue: T, _ oldValue: T) -> ()
    typealias ObserversEntry = (observer: AnyObject, block: ObserverBlock)
    private var observers: Array<ObserversEntry>
    
/*:
Now we'll need to implement an `init` for our class. The default initializer will simply take an initial value for the observable (declaration forthcoming). Given that we're writing Swift here, we'll need to initialize our non-optional `observers` array as well.
*/
    init(_ value: T) {
        self.value = value
        observers = []
    }
    
/*:
At this point, when we construct an `Observable` we'll have an initial value. This value is even assignable, but currently we don't have any way of telling the objects in our `observers` array that the value changed. To do this, we'll implement `didSet` for our `value` variable. All we need to do is loop through our listeners and call their associated blocks. Simple!
*/
    var value: T {
        didSet {
            observers.forEach { (entry: ObserversEntry) in
                let (_, block) = entry
                block(value, oldValue)
            }
        }
    }
    
/*:
Last but not least, the mechanism to notify observers is in place, but we have no way to update the `observers` array. We'll implement `subscribe` and `unsubscribe` to package up and add/remove observer tuples into the internal array.
*/
    func subscribe(observer: AnyObject, block: @escaping ObserverBlock) {
        let entry: ObserversEntry = (observer: observer, block: block)
        observers.append(entry)
    }

    func unsubscribe(observer: AnyObject) {
        let filtered = observers.filter { entry in
            let (owner, _) = entry
            return owner !== observer
        }
        
        observers = filtered
    }
}

/*:
That's all it takes!

**Note:** Please keep in mind that this is a simple, naïve, implementation without any considerations for performance, etc.

## Syntactic Sugar

While this works, I figured I could throw in just a little syntactic sugar to reduce the repetition of writing `foo.value = <value>`. I decided to override the `<<` operator:
*/
func <<<T>(observable: Observable<T>, value: T) {
    observable.value = value
}

/*:
**Update:** It appears I've been (fairly!) called out here by none other than [Chris Lattner](http://nondot.org/sabre/) (the designer of the Swift language) himself for overriding and repurposing the bit shift operator. 😉 I can't say I disagree: [Tweet Link](https://twitter.com/clattner_llvm/status/650354422430588928).

As such, if you use this code I'd recommend defining the `<~` operator instead, or something else similarly unique!
*/

/*: ## Example */
class ExampleStruct {
    var v: Int
    var obs: Observable<Int>

    init() {
        let initial = 3
        v = initial
        obs = Observable(initial)
    }
    
    func demo() {
        obs.subscribe(observer: self) { (newValue, oldValue) in
            self.v = newValue
        }
        
        obs << 4
        print(v)
    }
}

ExampleStruct().demo()  // Check the right side pane for values!
