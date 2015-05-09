
using PiecewiseAffineTransforms
using MultivariateStats
using ActiveAppearanceModels
using Images
using ImageView
using Color
using FaceDatasets
using Boltzmann
using HDF5, JLD


include("view.jl")


const DATA_DIR_CK = expanduser("~/work/ck-data")


function to_dataset(aam::AAModel, imgs::Vector{Matrix{Float64}},
                    shapes::Vector{Shape})
    warped1 = pa_warp(aam.wparams, imgs[1], shapes[1])
    v1 = to_vector(warped1, aam.wparams.warp_map)
    dataset = zeros(Float64, length(v1), length(imgs))
    for i=1:length(imgs)
        warped = pa_warp(aam.wparams, imgs[i], shapes[i])
        dataset[:, i] = to_vector(warped, aam.wparams.warp_map)
    end
    dataset
end


function to_vector{T}(img::Matrix{T}, mask::Matrix{Int})
    vec = Array(T, 0)
    for j=1:size(img, 2)
        for i=1:size(img, 1)
            if mask[i, j] > 0
                push!(vec, img[i, j])
            end
        end
    end
    vec
end

function to_image{T}(vec::Vector{T}, mask::Matrix{Int})
    img = zeros(T, size(mask))
    k = 1
    for j=1:size(img, 2)
        for i=1:size(img, 1)
            if mask[i, j] > 0
                img[i, j] = vec[k]
                k += 1
            end
        end
    end
    img
end


function normalize(img)
    mn, mx = minimum(img), maximum(img)
    nimg = (img .- mn) ./ (mx - mn)
    nimg
end


nview(img) = view(normalize(img))


function save_images{T,N}(imgs::Vector{Array{T,N}}, path::String; prefix="img")
    for i=1:length(imgs)
        img = normalize(imgs[i])
        imwrite(img, joinpath(path, @sprintf("%s_%03d.png", prefix, i)))
    end
end


function main()
    imgs = imgs = load_images(:ck, datadir=DATA_DIR_CK, resizeratio=0.5)
    shapes = load_shapes(:ck, datadir=DATA_DIR_CK, resizeratio=0.5)
    ## @time aam = train(AAModel(), imgs, shapes)

    ## indexes = rand(1:10708, 2048)
    ## imgs = load_images(:ck, datadir=DATA_DIR_CK, indexes=indexes, resizeratio=0.5)
    ## shapes = load_shapes(:ck, datadir=DATA_DIR_CK, indexes=indexes,
    ##                      resizeratio=0.5)
    @time aam = load(joinpath(DATA_DIR_CK, "aam.jld"))["aam"]    
    
    dataset = to_dataset(aam, imgs, shapes)
    mask = aam.wparams.warp_map
    
    rbm = GRBM(16177, 1024, sigma=0.001)
    @time fit(rbm, dataset, n_gibbs=3, lr=0.1, n_iter=3)


    P = projection(fit(PCA, dataset))
    nview(to_image(P[:, 1], aam.wparams.warp_map))
    pca_imgs = Matrix{Float64}[normalize(to_image(P[:, i], aam.wparams.warp_map))
                               for i=1:size(P, 2)]
    save_images(pca_imgs,
                expanduser("~/Dropbox/PhD/MyPapers/facial_expr_repr/images/pca"))

    
    comps = components(rbm)
    rbm_imgs = [to_image(comps[:, i], mask) for i=1:size(comps, 2)]
    nviewall(rbm_imgs[1:36])

    save_images(convert(Vector{Matrix{Float64}}, rbm_imgs),
                expanduser("~/Dropbox/PhD/MyPapers/facial_expr_repr/images/rbm"))
    
    h5open(joinpath(DATA_DIR_CK, "rbm_1_9591.h5"), "w") do h5
        save_params(h5, rbm, "rbm")
    end

    ## h5open(joinpath(DATA_DIR_CK, "rbm_1.jld")) do h5
    ##     rbm2 = save_params(h5, rbm, "rbm")
    ## end
    
end



# some results from previous experiments
# n_hid=192, n_gibbs=3, n_meta=10 ~ 7 faces of good quality
# n_hid=192, n_gibbs=5, n_meta=10 ~ 4 faces of good quality
# n_hid=256, n_gibbs=1, n_meta=10 ~ no faces at all
# n_hid=256, n_gibbs=3, n_meta=10 ~ 10 faces of almost good quality
# n_hid=256, n_gibbs=5, n_meta=10 ~ 11 faces of almost good quality
# n_hid=256, n_gibbs=10, n_meta=10 ~ 11 faces of almost good quality
# n_hid=256, n_gibbs=5, n_meta=20 ~ 12 faces of almost good quality
# n_hid=128, n_gibbs=3, n_meta=10 ~ all faces of bad quality
# n_hid=192, n_gibbs=3, n_meta=10 ~ 3 faces of a modate quality
# n_hid=256, n_gibbs=3, n_meta=10 ~ 10 faces of moderate quality
# n_hid=320, n_gibbs=3, n_meta=10 ~ 16 faces of almost good qualiy
# n_hid=384, n_gibbs=3, n_meta=10 ~ 17 faces of almost good qualiy
# n_hid=512, n_gibbs=3, n_meta=10 ~ 22 faces of different quality
# n_hid=768, n_gibbs=3, n_meta=10 ~ 25 faces of different quality
# n_hid=1024, n_gibbs=3, n_meta=10 ~ 21 face of different quality
# n_hid=768, n_gibbs=3, n_meta=10, sigma=0.001 ~ almost all faces!
# n_hid=512, n_gibbs=3, n_meta=10, sigma=0.001 ~ all good, but many similar
# n_hid=1024, n_gibbs=3, n_meta=10, sigma=0.001 ~ all good
# n_hid=128, n_gibbs=3, n_meta=10, lr=0.01 ~ 1 good, others similar and bad
# n_hid=128, n_gibbs=10, n_meta=10, lr=0.01 ~ 1 good, others similar and bad
# brbm: n_hid=768, n_gibbs=3, n_meta=10, lr=0.01 ~ 20 good
# grbm: n_hid=1024, n_gibbs=3, n_meta=10 ~ half almost good
# grbm: n_hid=768, n_gibbs=3, n_meta=10 ~ half almost good
# grbm: n_hid=1024, n_gibbs=10, n_meta=10 ~ half almost good
# grbm: n_hid=1024, n_gibbs=10, n_meta=3, lr=0.01 ~ half almost good
#! grbm: n_hid=1024, n_gibbs=3, n_meta=10, sigma=0.001, lr=0.01 ~ all really good!
# brbm: n_hid=1024, n_gibbs=3, n_meta=10, sigma=0.001, lr=0.01 ~ almost the same

# grbm (w/ momentum): n_hid=1024, n_gibbs=2, n_meta=5, sigma=0.001, lr=0.01 ~ 2243
