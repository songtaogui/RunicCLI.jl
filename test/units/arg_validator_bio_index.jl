@testset "arg_validator_bio_index" begin
    mktempdir() do d
        fa = joinpath(d, "ref.fa")
        open(fa, "w") do io
            write(io, ">a\nACGT\n")
        end
        open(fa * ".fai", "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_fa())(fa)

        gvcf = joinpath(d, "a.g.vcf.gz")
        open(gvcf, "w") do io
            write(io, "x")
        end
        open(gvcf * ".tbi", "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_gvcf())(gvcf)

        bam = joinpath(d, "a.bam")
        open(bam, "w") do io
            write(io, "x")
        end
        open(bam * ".bai", "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_xam())(bam)

        csi_target = joinpath(d, "a.cram")
        open(csi_target, "w") do io
            write(io, "x")
        end
        open(csi_target * ".csi", "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_csi())(csi_target)

        blast = joinpath(d, "db.fa")
        open(blast, "w") do io
            write(io, "x")
        end
        open(joinpath(d, "db.pin"), "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_blastdb())(blast)

        hisat_ref = joinpath(d, "genome.fa")
        open(hisat_ref, "w") do io
            write(io, "x")
        end
        for e in [".1.ht2", ".2.ht2", ".3.ht2", ".4.ht2", ".5.ht2", ".6.ht2", ".7.ht2", ".8.ht2"]
            open(joinpath(d, "genome" * e), "w") do io
                write(io, "idx")
            end
        end
        @test validator_fn(V_bioidx_hisat2())(hisat_ref)

        star_dir = joinpath(d, "staridx")
        mkpath(star_dir)
        for n in ["Genome", "SA", "SAindex"]
            open(joinpath(star_dir, n), "w") do io
                write(io, "idx")
            end
        end
        @test validator_fn(V_bioidx_star())(star_dir)

        diamond_ref = joinpath(d, "prot.faa")
        open(diamond_ref, "w") do io
            write(io, "x")
        end
        open(joinpath(d, "prot.dmnd"), "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_diamond())(diamond_ref)

        bt2_ref = joinpath(d, "bt2ref.fa")
        open(bt2_ref, "w") do io
            write(io, "x")
        end
        for e in [".1.bt2", ".2.bt2", ".3.bt2", ".4.bt2", ".rev.1.bt2", ".rev.2.bt2"]
            open(joinpath(d, "bt2ref" * e), "w") do io
                write(io, "idx")
            end
        end
        @test validator_fn(V_bioidx_bowtie2())(bt2_ref)

        bwa_ref = joinpath(d, "bwaref.fa")
        open(bwa_ref, "w") do io
            write(io, "x")
        end
        for e in [".amb", ".ann", ".bwt", ".pac", ".sa"]
            open(bwa_ref * e, "w") do io
                write(io, "idx")
            end
        end
        @test validator_fn(V_bioidx_bwa())(bwa_ref)

        salmon_dir = joinpath(d, "salmonidx")
        mkpath(salmon_dir)
        open(joinpath(salmon_dir, "hash.bin"), "w") do io
            write(io, "idx")
        end
        open(joinpath(salmon_dir, "versionInfo.json"), "w") do io
            write(io, "{}")
        end
        @test validator_fn(V_bioidx_salmon())(salmon_dir)

        kallisto_ref = joinpath(d, "kallisto.fa")
        open(kallisto_ref, "w") do io
            write(io, "x")
        end
        open(joinpath(d, "kallisto.idx"), "w") do io
            write(io, "idx")
        end
        @test validator_fn(V_bioidx_kallisto())(kallisto_ref)
    end
end
