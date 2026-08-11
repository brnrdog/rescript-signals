open Xote

@jsx.component
let make = () =>
  <div class="page">
    <Header />
    <main id="main-content" class="content">
      <Section__Hero />
      <Section__Demo />
      <Section__GettingStarted />
      <Section__Api />
      <Section__Changelog />
    </main>
    <Footer />
  </div>
