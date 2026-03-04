Function Process-Batch {
    <#
    .SYNOPSIS
    Process batches of pipeline input rather than the entire stream as one command.

    .DESCRIPTION
    Takes pipeline objects one at a time and sends them on in batches.  Allows user selectable values for
    batch size and feedback options.
    
    By design, each such array is output as a *single* object to the pipeline,
    so that the next command in the pipeline can process it as a whole.
    
    That is, for the next command in the pipeline $_ contains an *array* of
    (at most) as many elements as specified via -BatchSize.

    Even if a cmdlet accepts pipeline input, but has a limit to the number of objects it can accept at once, you can insert Process-Batch in between.
    But note that you need to use the ForEach-Object cmdlet to make it work right, in this general process:
    Imagine that the command MyCommand-ThatAcceptsPipelineInput will only accept up to 50 objects at a time. And, $MyCollectionOfObjects has 100 objects in it.
    If you run this
    $MyCollectionOfObjects | Process-Batch 50 | ForEach-Object { $_ | MyCommand-ThatAcceptsPipelineInput}
    then MyCommand-ThatAcceptsPipelineInput will run twice, each with 50 objects. If you don't use the ForEach-Object, then you'll effectively get just one stream and the command will error out.
    
    You could also do it like this without piping the objects into the final command:
    $MyCollectionOfObjects | Process-Batch 50 | ForEach-Object { My-Command -ArgumentThatAcceptsAnArray $_}
    
    .NOTES
    Source = https://stackoverflow.com/questions/61333235/batching-data-before-passing-through-the-pipeline
    Author = halfer
    Documentation modification and script name change by Roman Revell.

    Version 1   2023-08-26

    .PARAMETER InputObject
    The pipeline input objects bind to this parameter one by one.
    Do not use it directly.
    
    .PARAMETER BatchSize
    The desired size of the chunks, i.e., how many input objects to collect
    in an array before sending that array to the pipeline.
    
    0 effectively means: collect *all* inputs and output a single array overall.
    
    .EXAMPLE
    1..7 | Process-Batch 3 | ForEach-Object { "$_" }
    
    1 2 3
    4 5 6
    7
    
    The above shows that the ForEach-Object script block receives the following
    three arrays: (1, 2, 3), (4, 5, 6), and (, 7)
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param
    (
        # PipelineData
        [Alias('PipelineData')]
        [Parameter(ParameterSetName = 'Default', Mandatory, ValueFromPipeline)]
        [Parameter(ParameterSetName = 'Progress', Mandatory, ValueFromPipeline)]
        $InputObject,

        # Batch size for sending on to the pipeline
        [Parameter(ParameterSetName = 'Default', Position=0)]
        [Parameter(ParameterSetName = 'Progress', Position=0)]
        [int]$BatchSize = 50,

        # If set, Progress will use Write-Progress to display progress information
        [Parameter(ParameterSetName = 'Progress', Mandatory)]
        [switch]$Progress,

        # Passthru to Write-Progress ID parameter
        [Parameter(ParameterSetName = 'Progress')]
        [int]$ProgressID = 0,

        # Passthru to Write-Progress ParentID parameter
        [Parameter(ParameterSetName = 'Progress')]
        [int]$ProgressParentID = -1,

        # Passthru to Write-Progress Activity parameter. Default is 'Batching pipeline data'.
        [Parameter(ParameterSetName = 'Progress')]
        [int]$ProgressActivity = $null,

        # Report progress after this many records.  Defaults to same as BatchSize
        [Parameter(ParameterSetName = 'Progress')]
        [int]$ProgressBatchSize = $null,

        # Total Record count (if known) to be used in progress
        [Parameter(ParameterSetName = 'Progress')]
        [int]$TotalRecords = $null
    )

    Begin {
        $Batch = [System.Collections.Generic.Queue[pscustomobject]]::new($BatchSize)
        [int64]$RecordCounter = 0
        If ($Progress) {
            $ProgressParams = @{
                Activity        = If ($ProgressActivity) { $ProgressActivity } Else { 'Batching pipeline data' }
                Status          = ''
                ID              = $ProgressID
                ParentID        = $ProgressParentID
                PercentComplete = -1
            }
            If ($ProgressBatchSize -in $null, 0) { $ProgressBatchSize = $BatchSize }
        }
    }
    Process {
        $RecordCounter++

        #Add record to batch
        $Batch.Enqueue($_)

        #Report progress if necessary
        If ($Progress -and $RecordCounter % $ProgressBatchSize -eq 0) {
            If ($TotalRecords) {
                $ProgressParams.Status = "Piping record $RecordCounter/$TotalRecords"
                $ProgressParams.PercentComplete = [int](100 * ($RecordCounter / $TotalRecords))
            }
            Else {
                $ProgressParams.Status = "Piping record $RecordCounter"
            }
            Write-Progress @ProgressParams
        }

        #Pass batch on if it has reached its threshhold
        if ($Batch.Count -eq $BatchSize) { 
            , ($Batch)
            $Batch.Clear() # start next batch
        }
    }
    End {
        #Report final progress if necessary
        If ($Progress) {
            If ($TotalRecords) {
                $ProgressParams.Status = "Piping record $RecordCounter/$TotalRecords"
                $ProgressParams.PercentComplete = [int](100)
            }
            Else {
                $ProgressParams.Status = "Piping record $RecordCounter"
            }
            Write-Progress @ProgressParams
        }

        #Pass remaining records on and clear variable
        if ($Batch.count) {
            , ($Batch)
        }
        $Batch.Clear()
        Remove-Variable Batch

        #Clear progress bars if necessary
        If ($Progress) {
            $ProgressParams.Activity = 'Completed'
            If ($ProgressParams.ContainsKey('Status')) { $ProgressParams.Remove('Status') }
            Write-Progress @ProgressParams -Completed
        }
    }
}
Export-ModuleMember -Function Process-Batch