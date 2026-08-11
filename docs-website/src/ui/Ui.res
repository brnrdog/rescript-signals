%%raw(`import './ui.css'`)

// Minimal in-repo replacement for the parts of basefn this site used. Only the
// components and props the pages actually reach for are implemented here.

module Alert = Ui__Alert
module Button = Ui__Button
module Card = Ui__Card
module Grid = Ui__Grid
module Icon = Ui__Icon
module Input = Ui__Input
module Label = Ui__Label
module Select = Ui__Select
module Separator = Ui__Separator
module Spinner = Ui__Spinner
module Tabs = Ui__Tabs
module Typography = Ui__Typography

type selectOption = Ui__Select.selectOption
type tab = Ui__Tabs.tab
