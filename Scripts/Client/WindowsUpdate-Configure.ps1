[CmdletBinding()]param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Rest)
$target = Join-Path $PSScriptRoot '..\Server\WindowsUpdate-Configure.ps1'
& $target @Rest
