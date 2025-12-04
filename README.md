<img width="702" height="702" alt="image" src="https://github.com/user-attachments/assets/88c7cd5b-9ffa-45ca-8e48-7cdfc6c099a8" /># Journey

## Update 1

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

## Update 2

We will be designing the model now. We had another short meeting with Professor Jamali where she highlighted that exploring religious segregation might not be a very simple task. Some religious people live in small enclaves and groups around their specific dedicated prayer areas. We might introduce economic factors.

We have decided the following:
- 1 tick represents a year (people don't move about that often)
- Rather than neighbourhood-based segregation, we can have region-based segregation instead. This solves the issue of having enough people on the map and observing segregational visuals.
- For visualizing, we will have three choosers (Only a visual change):
  - `rel_lan_choose`: Choose between religion and language
  - `lan_choice`: Choose between the many languages being expressed in the model
  - `rel_choice`: Choose between the many religion being expressed in the model
- Heat Map (the same one being used can be used with different coloring schemes for different choices)
- Agents would be region-based. They would be populated based on current region population / some divider (for normalization of the agents; We can't populate 20 million agents!!!)
- Agents would decide to move on the basis of certain threshold parameters:
  - `Religious Tolerance`
  - `Linguistic Tolerance`
- These tolerances will be then compared with the ratios of the population of Religion/Language in the region of the agent to the total population in that region `(Pop Regional Metric / Total Regional Pop)`
- For now, the entire block of agents representing a larger population would move to a random new location.
- We will also be mapping population changes using census data: Birth Rates and Death Rates (These can also be parametrized)

## Update 3

I have worked on the agent part of the model. I have used ratios and the above design choice to spread agents. Below is the visual spread of agents with the following visual choices: `viz-mode`: Religion, `rel-focus`: Christian. 

<img width="702" height="702" alt="image" src="https://github.com/user-attachments/assets/591aba3f-19f3-4272-be68-445d8852b626" />

I have also added the `mouse-click-action-v2` function. I had to use patches for agent spread and easier placement. It required some mapping function to make sure that each patch corresponds to a certain map. An `agent-scale` value is privately stored in the code which converts the total population and other values into a smaller, reasonable number so that we can put in a set number of agents. Properties of each agent are assigned probabilistically using the embedded data in the shapefile. 

Speaking of the shapefile, I had to embed the rest of the values into the shapefile so I went back to the colab notebook and amended it to get the newer, updated version of the shapefile. 
Colab Notebook: https://colab.research.google.com/drive/1tUokU-Q6OZ9UZwSIdYc4dhyyWUdKtwjx?usp=sharing

There are also some other functional implementations committed to this and tested locally. The agent spread and data usage seems optimum and relevant (Could use a fresh pair of eyes though)... The next steps would be to implement the run-time aspect of this model... This would follow from our design earlier with tolerance thresholds deciding whether to stay in a region or not and then randomly shifting to a different region. This model should operate discretely. 
Population change factors using real birth rate and death rates of Pakistan can be used for demographic change and a different angle to study this model. Also, I think I placed the logic for "Others" as we are unable to map all the values from our census data since that data seemed to be insignificant (numerically!!!). The `update-visualization` function should just be called at the end of the `go` function whenever it is constructed for real-time segregational analysis. Also, this model shouldn't ideally run or more than a 100 ticks as each tick signifies an year: 2025 -> 2125. 
We can also consider adding further aspects to the shapefile such as economic factors... Certain regions signify certain kinds of economic statuses. Agents might move to only a status below, same or above... (Obviously, this is just me thinking out loud and nothing concrete as of yet)
