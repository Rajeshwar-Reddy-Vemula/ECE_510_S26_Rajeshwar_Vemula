## 1) What are you trying to do? Articulate your objectives using absolutely no jargon.

The goal is to build a specialized hardware "math engine" that finds patterns in images much faster than a standard computer chip. This process involves sliding a small window over a picture and doing many multiplications at once. While a regular chip does these one by one, my design does nine of them at the exact same time. This makes the process 7 times faster and saves a lot of battery life.

## 2) How is it done today, and what are the limits of current practice?

Today, this is done by general-purpose chips using software. These chips are "jacks-of-all-trades," meaning they have to stop and "think" about every instruction they receive. They also have a bad memory: they have to go back to the main storage thousands of times to fetch the same numbers over and over again. This wastes time and energy because the chip is built for general tasks, not for doing nine specific multiplications in a single heartbeat.

## 3) What is new in your approach and why do you think it will be successful?

My approach uses a custom circuit where the nine most important numbers are "locked" inside the chip so they never have to be fetched from memory again. I also added two small "storage rows" that act like a short-term memory, holding onto parts of the image so the chip doesn't have to re-read them.

This will succeed because the math shows that the "bottleneck" isn't moving the data—it's how fast we can do the math. By building a dedicated "fast lane" for these specific calculations, we remove all the software clutter. The design is simple and efficient, making it easy to build using modern chip-making tools.
