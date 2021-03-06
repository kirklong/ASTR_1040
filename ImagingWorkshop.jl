#!/usr/bin/env julia
using Plots, FITSIO, DataFrames, Statistics, StatsBase, Images
import FileIO

function main(shift=false)
    gr(format=:png); default(fontfamily="times",widen=false,tickdirection=:out,tickfontsize=18,guidefontsize=20) #plot defaults
    #READ IN DATA
    println("Hello! Reading in FITS files in this directory.")
    files = filter(endswith(".fits"),readdir()) #readdir() creates a list of files in the current directory, which we then `filter` to find only those that end with ".fits" since those are our images!
    test = FITS(files[1]) #let's see what one is like
    df = DataFrame(file = String[], filter = String[], exposure = Float64[]) #initialize an empty "DataFrame" (basically a fancy table) with keys "file", "filter", and "exposure" with types String, String, and Float64
    for f in files #iterate through every one of our files
        header = read_header(FITS(f)[1]) #read the header of the current file
        push!(df, [f, header["FILTER"], header["EXPOSURE"]]) #add the info to our fancy table
    end
    images = []; imageType = typeof(test[1]) #initialize empty images list, get the type of an image from our "test" sample above -- ImageHDU
    for f in files #loop through all the fits files
        fits = FITS(f) #get the data from FITSIO
        for hdu in fits #iterate through the different "header data units" in each fits
            if typeof(hdu) == imageType #is it an image?
                push!(images,read(hdu)) #plop it in our images list if the type matches!
            end
        end
    end
    images = [Int32.(images[i]) for i=1:length(images)]
    #IDENTIFY INDICES OF TYPES OF IMAGES
    darkInds = []; biasInds = []; flatInds = []; imgInds = []
    i=1
    for f in df.file
        if occursin("BIAS",f)==true
            push!(biasInds,i)
        elseif occursin("FLAT",f)==true
            push!(flatInds,i)
        elseif occursin("DARK",f)==true
            push!(darkInds,i)
        else
            push!(imgInds,i)
        end
        i+=1
    end
    #REDUCE DATA
    println("Files read in -- now reducing the data!")
    darkImgs = [images[i] for i in darkInds]#according to our table from before these ones were the "dark" frames
    darkMaster = zeros(size(darkImgs[1])) #let's initialize an array for our "master" dark frame that's the same size as the existing dark images
    for i=1:size(darkMaster)[1] #iterate through every x possibility
        for j=1:size(darkMaster)[2] #iterate through every y possibility
            darkMaster[i,j] = median([darkImgs[I][i,j] for I=1:length(darkImgs)]) #the "master" frame at position x,y (i,j) should be the median of the three initial dark frames at that same position
        end
    end

    #now let's do something similar for our bias images
    biasImgs = [images[i] for i in biasInds] #according to our table the first 3 were the bias images
    biasMaster = zeros(size(biasImgs[1])) #again we initialize an empty 2D array for our bias "master" that's the same size as one of the existing images
    for i=1:size(biasMaster)[1] #iterate through x
        for j=1:size(biasMaster)[2] #and y
            biasMaster[i,j] = median([biasImgs[I][i,j] for I=1:length(biasImgs)]) #again we set the master value at each x,y position to be the median of the three provided frames
        end
    end

    #and we'll do something slightly more complicated for the flat images
    flatImgs = [images[i] .- biasMaster for i in flatInds] #images 4-6 are the "flat" images, and we are subtracting the bias from them here
    flatImgs = flatImgs./(maximum(mode.(flatImgs))) #now we divide all of them by the maximum mode between them to rescale
    normFlatMaster = zeros(size(flatImgs[1])) #we again preallocate a matching 2D array that will be our "normalized flat master" image
    for i=1:size(normFlatMaster)[1] #loop x
        for j=1:size(normFlatMaster)[2] #and y
            normFlatMaster[i,j] = median([flatImgs[I][i,j] for I=1:length(flatImgs)]) #again we now set the x,y position of our master to be the median of the three existing images
        end
    end
    normFlatMaster = normFlatMaster./mode(normFlatMaster)

    #now let's reduce!
    rawImgs = [images[i] for i in imgInds]
    reduced = [(rawImgs[i] .- darkMaster)./normFlatMaster for i=1:length(rawImgs)]
    println("Data reduced -- now working on making a picture!")
    #match indices to reduced arrays
    i=1; rInd = nothing; gInd = nothing; bInd = nothing; cInd = nothing; otherFilters=[]
    for filter in df.filter
        if i ??? biasInds && i ??? flatInds && i ??? darkInds
            if filter == "Clear"
                cInd = i
            elseif filter == "Red"
                rInd = i
            elseif filter == "Green"
                gInd = i
            elseif filter == "Blue"
                bInd = i
            else 
                println("Detected non RGB filter: $filter with exposure time $(df.exposure[i])s -- adding it to list of potential substitutions")
                push!(otherFilters,(filter,i))
            end
        end
        i+=1
    end
    if rInd != nothing
        for i=1:length(imgInds)
            if imgInds[i] == rInd
                rInd = i
            end
        end
    end
    if gInd != nothing
        for i=1:length(imgInds)
            if imgInds[i] == gInd
                gInd = i
            end
        end
    end
    if bInd != nothing
        for i=1:length(imgInds)
            if imgInds[i] == bInd
                bInd = i
            end
        end
    end
    if cInd != nothing
        for i=1:length(imgInds)
            if imgInds[i] == cInd
                cInd = i
            end
        end
    end
    #now we can make the picture
    r,g,b = nothing, nothing, nothing
    if rInd != nothing && gInd != nothing && bInd != nothing
        r,g,b = reduced[rInd],reduced[gInd],reduced[bInd]
    else
        println("I don't have complete r,g,b set.")
        if length(otherFilters)>0
            println("I have these other filters available as substitutions:")
            count = 1
            for tup in otherFilters
                f,ind = tup
                println("$count: $filter")
                count+=1
            end
            if rInd == nothing
                print("Missing red filter -- select the number corresponding to filter in list above you would like to use to replace it (must be integer): ")
                tupInd = tryparse(Int64,readline())
                f,rInd = otherFilters[i]
            elseif gInd == nothing
                print("Missing green filter -- select the number corresponding to filter in list above you would like to use to replace it (must be integer): ")
                tupInd = tryparse(Int64,readline())
                f,gInd = otherFilters[i]
            elseif bInd == nothing
                print("Missing blue filter -- select the number corresponding to filter in list above you would like to use to replace it (must be integer): ")
                tupInd = tryparse(Int64,readline())
                f,bInd = otherFilters[i]
            end
            r,g,b = reduced[rInd],reduced[gInd],reduced[bInd]
        end
    end
    C = reduced[cInd]
    if r != nothing
        println("We have colors! Making a color image.")
        newImg = zeros(3,size(r)[2],size(r)[1]) #rgb,y,x
        for i=1:size(newImg)[1]
            for j=1:size(newImg)[3]
                for k=1:size(newImg)[2] #k,j swap rotates below
                    if i==1
                        newImg[i,k,j]= r[j,k] #red channel
                    elseif i==2
                        newImg[i,k,j]= g[j,k]#green channel
                    else
                        newImg[i,k,j]= b[j,k]#blue channel
                    end
                end
            end
        end
        img = newImg./(maximum(newImg)/30) #this controls the "exposure" -- /100 for overexposure to see galaxy
        rgbCube = reverse(img,dims=2) #reverse it? yes, this works and matches orientation of "real" pictures (fixes y direction)
        shape = size(rgbCube) #get the shape
        rgbCube = vec(rgbCube) #unravel it
        rgbCube[rgbCube.<0.0] .= 0.0; rgbCube[rgbCube.>1.0] .= 1.0 #make sure all the values are between 0 and 1
        rgbCube = reshape(rgbCube,shape)
        save("RGB.png",colorview(RGB,rgbCube)) #save the picture
        if shift == true
            img = FileIO.load("RGB.png")
            println("Look at the raw image and identify a region (in pixel coordinates) that has an isolated, bright star")
            endY=size(r)[2]
            YTicks=([endY-100*i for i=0:convert(Int64,floor(size(r)[2]/100))],["$(100*i)" for i=0:convert(Int64,floor(size(r)[2]/100))])
            XTicks=([100*i for i=0:convert(Int64,floor(size(r)[1]/100))],["$(100*i)" for i=0:convert(Int64,floor(size(r)[1]/100))])
            p=plot(img,aspect_ratio=:equal,grid=true,minorgrid=true,minorticks=5,yminorticks=5,xlabel="x (detector)",ylabel="y (detector)",
                size=size(r),yticks=YTicks,xticks=XTicks,bottom_margin=10*Plots.Measures.mm,left_margin=10*Plots.Measures.mm,xlims=(0,size(r)[1]),ylims=(0,size(r)[2]))
            p=vline!(xticks(p)[1][1],lc=:white,linealpha=0.5,label="")
            p=hline!(yticks(p)[1][1],lc=:white,linealpha=0.5,label="")
            display(p)
            print("Enter min x value (integer): ")
            minX = tryparse(Int64,readline())
            print("Enter max x value (integer): ")
            maxX = tryparse(Int64,readline())
            print("Enter min y value (integer): ")
            minY = tryparse(Int64,readline())
            print("Enter max y value (integer): ")
            maxY = tryparse(Int64,readline())
            println("Making image using matched centroids in specified region")
            function centroid(img,c,??x,??y) #get the centroid of a slice of an image
                xRange = [c[1]-??x,c[1]+??x]; yRange = [c[2]-??y,c[2]+??y]
                x = range(c[1]-??x,stop=c[1]+??x,length=2*??x+1); y = range(c[2]-??y,stop=c[2]+??y,length=2*??y+1)
                sub=img[xRange[1]:xRange[2],yRange[1]:yRange[2]] #image subsection bounded by xRange, yRange
                xIntensity = [sum(sub[i,:]) for i=1:size(sub)[1]]; yIntensity = [sum(sub[:,i]) for i=1:size(sub)[2]] #get the intensity in just the x and y directions
                xCen = sum(xIntensity.*x)/sum(xIntensity); yCen = sum(yIntensity.*y)/sum(yIntensity) #calculate the centroids using weighted average formula
                return round(xCen), round(yCen) #return them rounded to nearest integer (pixel)
            end
            c = convert.(Int64,[floor((minX+maxX)/2),floor((minY+maxY)/2)])
            ??x = convert(Int64,(maxX-minX)/2); ??y = convert(Int64,(maxY-minY)/2)
            rCenX,rCenY = centroid(r,c,??x,??y)
            gCenX,gCenY = centroid(g,c,??x,??y)
            bCenX,bCenY = centroid(b,c,??x,??y)
            ??xg = convert(Int64,rCenX-gCenX); ??yg = convert(Int64,rCenY-gCenY)
            ??xb = convert(Int64,rCenX-bCenX); ??yb = convert(Int64,rCenY-bCenY)
            ??xSigned = [??xg,??xb]; ??ySigned = [??yg,??yb]
            ??x,indX = findmax(abs.(??xSigned)); ??y,indY = findmax(abs.(??ySigned))
            rgLeft = 0; rbLeft = 0; rgDown = 0; rbDown = 0
            ??x = convert(Int64,??x); ??y = convert(Int64,??y)

            newImg = zeros(3,size(r)[2]-??y,size(r)[1]-??x)
            ??x = ??xSigned[indX]; ??y = ??ySigned[indY]
            rLAdd = 0; rDAdd = 0; bLAdd = 1; bDAdd = 1; gLAdd = 1; gDAdd = 1 #they should start as opposites
            if ??x > 0
                rLAdd = 1
                if ??x == ??xg
                    gLAdd = 0 #this is the one we're matching "to", it should be opposite
                elseif ??x == ??xb
                    bLAdd = 0
                end
            end

            if ??y > 0
                rDAdd = 1
                if ??y == ??yg
                    gDAdd = 0
                elseif ??y == ??yb
                    bDAdd = 0
                end
            end
            ??x = abs(??x); ??y = abs(??y); ??xg = abs(??xg); ??xb = abs(??xb); ??yg = abs(??yg); ??yb = abs(??yb)
            for i=1:size(newImg)[1]
                for j=1:size(newImg)[3]
                    for k=1:size(newImg)[2] #k,j swap rotates below, no longer dividing by clear image, instead normalizing different way
                        if i==1
                            newImg[i,k,j]= r[j+??x*rLAdd,k+??y*rDAdd] #red
                        elseif i==2
                            newImg[i,k,j]= g[j+??xg*gLAdd,k+??yg*gDAdd]#green
                        else
                            newImg[i,k,j]= b[j+??xb*bLAdd,k+??yb*bDAdd]#blue
                        end
                    end
                end
            end
            satSample = [1,10,25,50,100,200]
            for sat in satSample
                img = newImg./(maximum(newImg)/sat)
                rgbCube = reverse(img,dims=2) #reverse it? yes, this works and matches orientation of "real" pictures (fixes y direction)
                shape = size(rgbCube)
                rgbCube = vec(rgbCube)
                rgbCube[rgbCube.<0.0] .= 0.0; rgbCube[rgbCube.>1.0] .= 1.0
                rgbCube = reshape(rgbCube,shape)
                save("RGB_sat_$sat.png",colorview(RGB,rgbCube)) #save the picture
            end
            p=plot(layout=grid(2,3),size=(1920,1080),showaxis=false)
            for i=1:length(satSample)
                img = FileIO.load("RGB_sat_$(satSample[i]).png")
                plot!(p[i],img,title="Saturation = $(satSample[i])",showaxis=false,xticks=false,yticks=false)
            end
            display(p)
            print("Select saturation level using samples below (must be integer): ")
            sat = tryparse(Int64,readline())
            foreach(rm,["RGB_sat_$s.png" for s in satSample]) #clean up files
            println("Making final image -- saving as RBG_FINAL_sat_$sat.png")
            img = newImg./(maximum(newImg)/sat)
            rgbCube = reverse(img,dims=2) #reverse it? yes, this works and matches orientation of "real" pictures (fixes y direction)
            shape = size(rgbCube)
            rgbCube = vec(rgbCube)
            rgbCube[rgbCube.<0.0] .= 0.0; rgbCube[rgbCube.>1.0] .= 1.0
            rgbCube = reshape(rgbCube,shape)
            save("RGB_Final_sat_$sat.png",colorview(RGB,rgbCube)) #save the picture
        end
    else
        println("Could not detect r,g,b channels -- making a B&W image.")
        p = heatmap(C',c=:bone,aspect_ratio=:equal,clim=(0,1000),xlabel="x (detector)",ylabel="y (detector)",
        title = "Clear reduced image, saturated at 1000 counts",grid=false,
        xlims=(0,size(C)[1]),ylims=(0,size(C)[2]))
        png(p,"Clear.png")
    end
end

main(true)
