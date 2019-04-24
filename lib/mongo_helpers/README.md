Provides functions for creating data structures to be passed to MongoDB, and allows you to do data-type validation and casting and other neat stuff.

You basically build query sets which are then executed with the query manager. The query manager will take your Mongo repo (which should be managed by something like Poolboy) and put the queryset through several casts (for validation). Somewhere long ago in another codebase there was more to this, unfortunately this is all I could salvage (for now).
