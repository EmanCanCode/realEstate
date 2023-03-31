(function () {
  document.addEventListener('DOMContentLoaded', function () {
    const fetchNav = async () => {
      const navElement = document.querySelector('.nav-container');
      try {
        const res = await fetch('../common/nav.html');
        const navTemplate = await res.text();
        navElement.innerHTML = navTemplate;
      } catch (err) {
        console.log(err);
      }
    };
    const fetchFooter = async () => {
      const footerElement = document.querySelector('.footer-container');
      try {
        const res = await fetch('../common/footer.html');
        const footerTemplate = await res.text();
        footerElement.innerHTML = footerTemplate;
      } catch (err) {
        console.log(err);
      }
    };
    fetchNav();
    fetchFooter();
  });
})();
