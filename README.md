Journey

It started off as a general idea to study economic, ethnic and religious segregation in Karachi. The idea was to use Schelling's model and apply Bruch's methodology to it by using real
emperical data. (Will talk about Bridge agents as well... something new that we are trying to build xD)

After discussions with Professor Shah Jamal, we reached a conclusion that this wouldn't be very feasible as the scope is too broad... (We could use the Kids to Kiss procedure here but
time constraints aren't a joke)

We shifted our idea slightly by proposing that we study Religious and Linguistic affects on segregation instead. We then approached Professor Jamali for guidelines regarding data and how
can we proceed in this endeavour. She guided us really well and we found very relevant and accurate census data which had exactly what we needed.

Then, we had another meeting with Professor Shah Jamal in which we were given a shapefile for karachi. However, that was a very old shapefile. Merging the demographic data with the
geographic/administrative was almost hell...

I spent 3 hours trying to get it running when I gave up... I knew that I should instead try to find a new shapefile... one which was more recent...
That was when I came across: https://data.humdata.org/dataset/cod-ab-pak
This contained the relevant shapefile related data for ADM2 and ADM3 (District and Tehsil level). However, this was the data for entire Pakistan.

I spent the next few hours trying to extract the karachi level data... The same issue of data mismatching occured in this as well... I had to change the vectors and use some methods
by using the geopandas library to amend the shapefile.

After that, I spent quite some time trying to load the shapefile up in NetLogo. This was more-or-less easier. However, debugging and properly visualizing took some time. I tried rasterizing
(using pixel based representation) but that seemed buggy and incorrect. Then, i shifted to pure vector based visualization. I color graded the districts based on population until I got
this result:

![Initial Color-based representation for the population distribution of Karachi](https://github.com/user-attachments/assets/59dc4a90-da30-4df2-85db-e84db13f52e8)
